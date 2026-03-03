#include "Vcpu_verilator_bridge.h"
#include "Vcpu_verilator_bridge___024root.h"
#include "verilated.h"

#if VM_TRACE
    #include "verilated_vcd_c.h"
#endif

extern "C"
{
#include "gbit/lib/tester.h"
}

#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>

namespace {

class CpuTopRunner
{
  public:
    CpuTopRunner() = default;

    ~CpuTopRunner()
    {
#if VM_TRACE
        if (tfp_) {
            tfp_->close();
            delete tfp_;
            tfp_ = nullptr;
            printf("trace closed\n");
        }
#endif
        top_.final();
    }

    void initialize(size_t instruction_mem_size, uint8_t *instruction_mem)
    {
        instruction_mem_size_ = instruction_mem_size;
        instruction_mem_ = instruction_mem;

#if VM_TRACE
        if (!tfp_) {
            Verilated::traceEverOn(true);
            tfp_ = new VerilatedVcdC();
            top_.trace(tfp_, 99);
            const char *trace_file = std::getenv("GBIT_TRACE_FILE");
            if (!trace_file)
                trace_file = "gbit_out.vcd";
            tfp_->open(trace_file);
        }
#endif

        hard_reset();
    }

    void set_state(const state *s)
    {

        num_mem_accesses_ = 0;
        std::memset(memory_.data(), 0xAA, memory_.size());
        for (size_t i = 0; i < instruction_mem_size_; ++i) {
            memory_[i] = instruction_mem_[i];
        }
        hard_reset();

        auto *root = top_.rootp;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__AF_reg = s->reg16.AF;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__BC_reg = s->reg16.BC;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__DE_reg = s->reg16.DE;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__HL_reg = s->reg16.HL;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__SP_reg = s->SP;
        root->cpu_verilator_bridge__DOT__uut__DOT__reg_file__DOT__PC_reg = s->PC;
        root->cpu_verilator_bridge__DOT__uut__DOT__control_unit__DOT__halt = s->halted ? 1 : 0;
        root->cpu_verilator_bridge__DOT__uut__DOT__control_unit__DOT__ime = s->interrupts_master_enabled ? 1 : 0;

        top_.eval();
    }

    void get_state(state *s)
    {
        s->PC = static_cast<uint16_t>(top_.PC_out);
        s->SP = static_cast<uint16_t>(top_.SP_out);
        s->reg16.AF = static_cast<uint16_t>(top_.AF_out);
        s->reg16.BC = static_cast<uint16_t>(top_.BC_out);
        s->reg16.DE = static_cast<uint16_t>(top_.DE_out);
        s->reg16.HL = static_cast<uint16_t>(top_.HL_out);
        s->halted = top_.halted_out != 0;
        s->interrupts_master_enabled = top_.ime_out != 0;
        s->num_mem_accesses = num_mem_accesses_;
        std::memcpy(s->mem_accesses, mem_accesses_.data(), sizeof(struct mem_access) * mem_accesses_.size());
    }

    void print_register_state(int cycle) const
    {
        std::cout << "cycle=" << cycle << " AF=" << static_cast<unsigned>(top_.AF_out) << " BC=" << static_cast<unsigned>(top_.BC_out)
                  << " DE=" << static_cast<unsigned>(top_.DE_out) << " HL=" << static_cast<unsigned>(top_.HL_out)
                  << " SP=" << static_cast<unsigned>(top_.SP_out) << " PC=" << static_cast<unsigned>(top_.PC_out) << std::endl;
    }

    int step_instruction()
    {
        int m_cycles = 0;

        do {
            tick();
            m_cycles += 4;
        } while (static_cast<uint16_t>(top_.m_cycle_out) != 0);

        return m_cycles;
    }

  private:
    void hard_reset()
    {
        top_.clk = 0;
        top_.rst = 1;
        tick();
        tick();
        top_.rst = 0;
    }

    void log_write(uint16_t addr, uint8_t value)
    {
        if (num_mem_accesses_ < static_cast<int>(mem_accesses_.size())) {
            struct mem_access &entry = mem_accesses_[num_mem_accesses_++];
            entry.type = MEM_ACCESS_WRITE;
            entry.addr = addr;
            entry.val = value;
        }
    }

    void eval_with_trace()
    {
        top_.eval();
#if VM_TRACE
        if (tfp_) {
            tfp_->dump(sim_time_);
        }
#endif
        sim_time_++;
    }

    void tick()
    {
        top_.clk = 0;
        eval_with_trace();

        const uint16_t addr = static_cast<uint16_t>(top_.addr_out);
        const bool     write_en = top_.wr_en != 0;
        const uint8_t  write_data = static_cast<uint8_t>(top_.data_out);

        if (top_.rd_en) {
            top_.data_in = memory_[addr];
        } else {
            top_.data_in = 0;
        }

        top_.clk = 1;
        eval_with_trace();

        if (write_en) {
            memory_[addr] = write_data;
            log_write(addr, write_data);
        }
    }

    Vcpu_verilator_bridge top_;
    uint64_t              sim_time_ = 0;
#if VM_TRACE
    VerilatedVcdC *tfp_ = nullptr;
#endif
    std::array<uint8_t, 65536>        memory_{};
    std::array<struct mem_access, 16> mem_accesses_{};
    int                               num_mem_accesses_ = 0;
    size_t                            instruction_mem_size_ = 0;
    uint8_t                          *instruction_mem_ = nullptr;
    uint16_t                          last_pc;
};

CpuTopRunner g_runner;

void mycpu_init(size_t tester_instruction_mem_size, uint8_t *tester_instruction_mem)
{
    g_runner.initialize(tester_instruction_mem_size, tester_instruction_mem);
}

void mycpu_set_state(struct state *state)
{
    g_runner.set_state(state);
}

void mycpu_get_state(struct state *state)
{
    g_runner.get_state(state);
}

int mycpu_step(void)
{
    return g_runner.step_instruction();
}

} // namespace

extern "C" struct tester_operations myops = {
    .init = mycpu_init,
    .set_state = mycpu_set_state,
    .get_state = mycpu_get_state,
    .step = mycpu_step,
};
