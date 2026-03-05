#include "Vtop_verilator_bridge.h"
#include "Vtop_verilator_bridge___024root.h"
#include "verilated.h"

#if VM_TRACE
    #include "verilated_vcd_c.h"
#endif

#include <array>
#include <cstdint>
#include <iomanip>
#include <iostream>

namespace {

#if VM_TRACE
uint64_t       sim_time = 0;
VerilatedVcdC *g_trace = nullptr;

void dump_trace(Vtop_verilator_bridge &dut)
{
    if (g_trace) {
        g_trace->dump(sim_time);
    }
    sim_time++;
}
#endif

void print_state(const Vtop_verilator_bridge &dut)
{

    printf(
        "A: %02X F: %02X B: %02X C: %02X D: %02X E: %02X H: %02X L: %02X SP: %04X PC: 00:%04X (%02X %02X %02X %02X)\n",
        dut.AF_out >> 8,
        dut.AF_out & 0xFF,
        dut.BC_out >> 8,
        dut.BC_out & 0xFF,
        dut.DE_out >> 8,
        dut.DE_out & 0xFF,
        dut.HL_out >> 8,
        dut.HL_out & 0xFF,
        dut.SP_out,
        dut.executing_pc_out,
        dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom[static_cast<uint16_t>(dut.executing_pc_out)],
        dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom[static_cast<uint16_t>(dut.executing_pc_out) + 1],
        dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom[static_cast<uint16_t>(dut.executing_pc_out) + 2],
        dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom[static_cast<uint16_t>(dut.executing_pc_out) + 3]);
}

void tick(Vtop_verilator_bridge &dut, std::array<uint8_t, 65536> &ram)
{
    dut.clk = 0;
    dut.eval();
#if VM_TRACE
    dump_trace(dut);
#endif

    if (dut.cart_re) {
        dut.cart_din = ram[static_cast<uint16_t>(dut.cart_addr)];
    } else {
        dut.cart_din = 0x00;
    }

    dut.clk = 1;
    dut.eval();
#if VM_TRACE
    dump_trace(dut);
#endif

    if (dut.cart_we) {
        ram[static_cast<uint16_t>(dut.cart_addr)] = static_cast<uint8_t>(dut.cart_dout);
    }
}

void reset(Vtop_verilator_bridge &dut, std::array<uint8_t, 65536> &ram)
{
    dut.rst = 1;
    dut.cart_din = 0xFF;

    tick(dut, ram);
    tick(dut, ram);
    dut.rst = 0;
    tick(dut, ram);
}

void step_instruction(Vtop_verilator_bridge &dut, std::array<uint8_t, 65536> &ram)
{
    tick(dut, ram);
    auto cur_copcode = dut.rootp->top_verilator_bridge__DOT__uut__DOT__CPU__DOT__opcode;
    auto pc = dut.rootp->top_verilator_bridge__DOT__uut__DOT__CPU__DOT__reg_file__DOT__PC_reg;
    // printf("Executing instruction: 0x%02X at PC=0x%04X\n", cur_copcode, pc);

    while (static_cast<uint16_t>(dut.m_cycle_out) != 0) {
        tick(dut, ram);
    };
}

void disable_bootrom(Vtop_verilator_bridge &dut)
{
    dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom_mapped = 0;
    dut.eval();
}

} // namespace

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    Vtop_verilator_bridge      dut;
    std::array<uint8_t, 65536> ram{};

#if VM_TRACE
    Verilated::traceEverOn(true);
    VerilatedVcdC trace;
    g_trace = &trace;
    dut.trace(&trace, 99);
    trace.open("top_out.vcd");
#endif

    ram.fill(0x00);

    // Set Nintendo logo in ram
    const std::array<uint8_t, 48> nintendo_logo = {0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
                                                   0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
                                                   0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E};

    std::copy(nintendo_logo.begin(), nintendo_logo.end(), ram.begin() + 0x0104);

    reset(dut, ram);
    // disable_bootrom(dut);

    print_state(dut);

    for (int i = 0; i < 47932 + 5; ++i) {
        step_instruction(dut, ram);
        print_state(dut);
        if (dut.halted_out) {
            break;
        }
    }

    // Debug: Print bootrom content after execution
    // auto rom = dut.rootp->top_verilator_bridge__DOT__uut__DOT__bus_inst__DOT__bootrom;
    // std::cout << "Boot ROM content after execution:" << std::endl;
    // for (size_t i = 0; i < 256; ++i) {
    //     printf("0x%02X ", rom[i]);
    //     if ((i + 1) % 16 == 0) {
    //         printf("\n");
    //     }
    // }

#if VM_TRACE
    trace.close();
    g_trace = nullptr;
#endif
    dut.final();
    return 0;
}
