import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from test_utils import CPUMemory, reset_cpu, do_cycles

@cocotb.test()
async def test_nop(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x00])
    await reset_cpu(dut)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert dut.reg_file.PC_reg.value.integer == 1, f"PC should be 1, got {dut.reg_file.PC_reg.value.integer}"

@cocotb.test()
async def test_ld_a16_sp(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x08, 0x34, 0x12])
    await reset_cpu(dut)
    dut.reg_file.SP_reg.value = 0xABCD
    await do_cycles(dut, 5)
    actual_low = mem.data.get(0x1234, 0)
    actual_high = mem.data.get(0x1235, 0)
    actual = (actual_high << 8) | actual_low
    assert actual == 0xABCD, f"LD (a16), SP failed: expected 0xABCD, got {hex(actual)}"

@cocotb.test()
async def test_ld_bc_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x02])
    await reset_cpu(dut)
    dut.reg_file.BC_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0x4200
    await do_cycles(dut, 2)
    actual = mem.data.get(0x8000, 0)
    assert actual == 0x42, f"LD (BC), A failed: expected 0x42, got {hex(actual)}"

@cocotb.test()
async def test_ld_de_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x12])
    await reset_cpu(dut)
    dut.reg_file.DE_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0x4200
    await do_cycles(dut, 2)
    actual = mem.data.get(0x8000, 0)
    assert actual == 0x42, f"LD (DE), A failed: expected 0x42, got {hex(actual)}"

@cocotb.test()
async def test_ld_a_bc_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x0A], data={0x8000: 0x42})
    await reset_cpu(dut)
    dut.reg_file.BC_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0
    await do_cycles(dut, 2)
    actual = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert actual == 0x42, f"LD A, (BC) failed: expected 0x42, got {hex(actual)}"

@cocotb.test()
async def test_ld_a_de_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x1A], data={0x8000: 0x42})
    await reset_cpu(dut)
    dut.reg_file.DE_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0
    await do_cycles(dut, 2)
    actual = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert actual == 0x42, f"LD A, (DE) failed: expected 0x42, got {{hex(actual)}}"

@cocotb.test()
async def test_ld_hl_inc_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x22])
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0x4200
    await do_cycles(dut, 2)
    actual = mem.data.get(0x8000, 0)
    actual_hl = dut.reg_file.HL_reg.value.integer
    assert actual == 0x42, f"LD (HL+), A failed: expected memory == 0x42, got {{hex(actual)}}"
    assert actual_hl == 0x8001, f"LD (HL+), A failed: expected HL == 0x8001, got {{hex(actual_hl)}}"

@cocotb.test()
async def test_ld_hl_dec_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x32])
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0x4200
    await do_cycles(dut, 2)
    actual = mem.data.get(0x8000, 0)
    actual_hl = dut.reg_file.HL_reg.value.integer
    assert actual == 0x42, f"LD (HL-), A failed: expected memory == 0x42, got {{hex(actual)}}"
    assert actual_hl == 0x7FFF, f"LD (HL-), A failed: expected HL == 0x7FFF, got {{hex(actual_hl)}}"

@cocotb.test()
async def test_ld_a_hl_inc_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x2A], data={0x8000: 0x42})
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0
    await do_cycles(dut, 2)
    actual = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_hl = dut.reg_file.HL_reg.value.integer
    assert actual == 0x42, f"LD A, (HL+) failed: expected A == 0x42, got {{hex(actual)}}"
    assert actual_hl == 0x8001, f"LD A, (HL+) failed: expected HL == 0x8001, got {{hex(actual_hl)}}"

@cocotb.test()
async def test_ld_a_hl_dec_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x3A], data={0x8000: 0x42})
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0
    await do_cycles(dut, 2)
    actual = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_hl = dut.reg_file.HL_reg.value.integer
    assert actual == 0x42, f"LD A, (HL-) failed: expected A == 0x42, got {{hex(actual)}}"
    assert actual_hl == 0x7FFF, f"LD A, (HL-) failed: expected HL == 0x7FFF, got {{hex(actual_hl)}}"

@cocotb.test()
async def test_rlca_carry_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x07])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8500
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x0B, f"RLCA failed: expected A=0x0B, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RLCA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rlca_carry_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x07])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x4210  # carry initially set
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x84, f"RLCA failed: expected A=0x84, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x00, f"RLCA failed: expected CY=0, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rrca_carry_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x0F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8500
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0xC2, f"RRCA failed: expected A=0xC2, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RRCA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rrca_carry_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x0F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8410  # carry initially set
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x42, f"RRCA failed: expected A=0x42, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x00, f"RRCA failed: expected CY=0, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rla_carry_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x17])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8500
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x0A, f"RLA failed: expected A=0x0A, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RLA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rla_carry_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x17])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8510
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x0B, f"RLA failed: expected A=0x0B, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RLA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rra_carry_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x1F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8500
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x42, f"RRA failed: expected A=0x42, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RRA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_rra_carry_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x1F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x8510
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0xC2, f"RRA failed: expected A=0xC2, got {{hex(actual_a)}}"
    assert (actual_f & 0x1) == 0x01, f"RRA failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_daa_1(dut):
    # From the Game Pack Programming Manual, page 122
    # Examples: When A = 45h and B = 38h, ADD A, B  ;  A <- 7Dh, N <- 0
    # DAA ;  A <-7Dh + 06h (83h), CY <- 0
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x27])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x7D00
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x83, f"DAA 1 failed: expected A=0x83, got {{hex(actual_a)}}"
    assert actual_f == 0x00, f"DAA 1 failed: expected F=0x00, got {{hex(actual_f)}}"

@cocotb.test()
async def test_daa_2(dut):
    # SUB A, B  ;  A <- 83h - 38h (4Bh), N <- 1
    # DAA ;  A <- 4Bh + FAh (45h)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x27])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x4B60 # N (0x40) + H (0x20)
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x45, f"DAA 2 failed: expected A=0x45, got {{hex(actual_a)}}"
    assert actual_f == 0x04, f"DAA 2 failed: expected F=0x04 (SUB), got {{hex(actual_f)}}"

@cocotb.test()
async def test_cpl(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x2F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0xAA00
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x55, f"CPL failed: expected A=0x55, got {{hex(actual_a)}}"
    assert (actual_f & 0x6) == 0x06, f"CPL failed: expected N=1 H=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_scf(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x37])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0000
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (actual_f & 0x1) == 0x01, f"SCF failed: expected CY=1, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_ccf_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x3F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0010
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (actual_f & 0x1) == 0x00, f"CCF failed: expected CY=0, got F={{hex(actual_f)}}"

@cocotb.test()
async def test_ccf_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x3F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0000
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (actual_f & 0x1) == 0x01, f"CCF failed: expected CY=1, got F={{hex(actual_f)}}"
