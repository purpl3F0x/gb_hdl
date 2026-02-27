import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from test_utils import CPUMemory, do_cycles, reset_cpu


@cocotb.test()
async def test_nop(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x00])
    await reset_cpu(dut)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert (
        dut.reg_file.PC_reg.value.integer == 1
    ), f"PC should be 1, got {dut.reg_file.PC_reg.value.integer}"


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
    assert (
        actual == 0x42
    ), f"LD (HL+), A failed: expected memory == 0x42, got {{hex(actual)}}"
    assert (
        actual_hl == 0x8001
    ), f"LD (HL+), A failed: expected HL == 0x8001, got {{hex(actual_hl)}}"


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
    assert (
        actual == 0x42
    ), f"LD (HL-), A failed: expected memory == 0x42, got {{hex(actual)}}"
    assert (
        actual_hl == 0x7FFF
    ), f"LD (HL-), A failed: expected HL == 0x7FFF, got {{hex(actual_hl)}}"


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
    assert (
        actual == 0x42
    ), f"LD A, (HL+) failed: expected A == 0x42, got {{hex(actual)}}"
    assert (
        actual_hl == 0x8001
    ), f"LD A, (HL+) failed: expected HL == 0x8001, got {{hex(actual_hl)}}"


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
    assert (
        actual == 0x42
    ), f"LD A, (HL-) failed: expected A == 0x42, got {{hex(actual)}}"
    assert (
        actual_hl == 0x7FFF
    ), f"LD A, (HL-) failed: expected HL == 0x7FFF, got {{hex(actual_hl)}}"


@cocotb.test()
async def test_ld_sp_hl(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xF9])
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0xBEEF
    dut.reg_file.SP_reg.value = 0x0000
    await do_cycles(dut, 2)
    actual = dut.reg_file.SP_reg.value.integer
    assert actual == 0xBEEF, f"LD SP, HL failed: expected 0xBEEF, got {hex(actual)}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RLCA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x00, f"RLCA failed: expected CY=0, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RRCA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x00, f"RRCA failed: expected CY=0, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RLA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RLA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RRA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    assert (
        actual_f & 0x1
    ) == 0x01, f"RRA failed: expected CY=1, got F={{hex(actual_f)}}"


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
    dut.reg_file.AF_reg.value = 0x4B60  # N (0x40) + H (0x20)
    await do_cycles(dut, 1)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert actual_a == 0x45, f"DAA 2 failed: expected A=0x45, got {{hex(actual_a)}}"
    assert (
        actual_f == 0x04
    ), f"DAA 2 failed: expected F=0x04 (SUB), got {{hex(actual_f)}}"


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
    assert (
        actual_f & 0x6
    ) == 0x06, f"CPL failed: expected N=1 H=1, got F={{hex(actual_f)}}"


@cocotb.test()
async def test_scf(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x37])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0000
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (
        actual_f & 0x1
    ) == 0x01, f"SCF failed: expected CY=1, got F={{hex(actual_f)}}"


@cocotb.test()
async def test_ccf_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x3F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0010
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (
        actual_f & 0x1
    ) == 0x00, f"CCF failed: expected CY=0, got F={{hex(actual_f)}}"


@cocotb.test()
async def test_ccf_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x3F])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = 0x0000
    await do_cycles(dut, 1)
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F
    assert (
        actual_f & 0x1
    ) == 0x01, f"CCF failed: expected CY=1, got F={{hex(actual_f)}}"


@cocotb.test()
async def test_add_hl_bc_no_carry_no_halfcarry(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x09])  # ADD HL,BC
    await reset_cpu(dut)

    dut.reg_file.HL_reg.value = 0x1234
    dut.reg_file.BC_reg.value = 0x1111
    dut.reg_file.AF_reg.value = 0x5580  # A=0x55, Z=1 (should be preserved)

    await do_cycles(dut, 2)

    actual_hl = dut.reg_file.HL_reg.value.integer
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F

    assert (
        actual_hl == 0x2345
    ), f"ADD HL,BC failed: expected HL=0x2345, got {hex(actual_hl)}"
    assert (
        actual_a == 0x55
    ), f"ADD HL,BC failed: A should be unchanged, got {hex(actual_a)}"
    assert (
        actual_f & 0x8
    ) == 0x8, f"ADD HL,BC failed: Z should be preserved, got F={hex(actual_f)}"
    assert (
        actual_f & 0x4
    ) == 0x0, f"ADD HL,BC failed: N should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x2
    ) == 0x0, f"ADD HL,BC failed: H should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x0, f"ADD HL,BC failed: C should be 0, got F={hex(actual_f)}"


@cocotb.test()
async def test_add_hl_bc_halfcarry(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x09])  # ADD HL,BC
    await reset_cpu(dut)

    dut.reg_file.HL_reg.value = 0x0FFF
    dut.reg_file.BC_reg.value = 0x0001
    dut.reg_file.AF_reg.value = 0x0080  # Z=1 (should be preserved)

    await do_cycles(dut, 2)

    actual_hl = dut.reg_file.HL_reg.value.integer
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F

    assert (
        actual_hl == 0x1000
    ), f"ADD HL,BC failed: expected HL=0x1000, got {hex(actual_hl)}"
    assert (
        actual_f & 0x8
    ) == 0x8, f"ADD HL,BC failed: Z should be preserved, got F={hex(actual_f)}"
    assert (
        actual_f & 0x4
    ) == 0x0, f"ADD HL,BC failed: N should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x2
    ) == 0x2, f"ADD HL,BC failed: H should be 1, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x0, f"ADD HL,BC failed: C should be 0, got F={hex(actual_f)}"


@cocotb.test()
async def test_add_hl_de_carry_and_halfcarry(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x19])  # ADD HL,DE
    await reset_cpu(dut)

    dut.reg_file.HL_reg.value = 0xFFFF
    dut.reg_file.DE_reg.value = 0x0001
    dut.reg_file.AF_reg.value = 0x0080  # Z=1 (should be preserved)

    await do_cycles(dut, 2)

    actual_hl = dut.reg_file.HL_reg.value.integer
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F

    assert (
        actual_hl == 0x0000
    ), f"ADD HL,DE failed: expected HL=0x0000, got {hex(actual_hl)}"
    assert (
        actual_f & 0x8
    ) == 0x8, f"ADD HL,DE failed: Z should be preserved, got F={hex(actual_f)}"
    assert (
        actual_f & 0x4
    ) == 0x0, f"ADD HL,DE failed: N should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x2
    ) == 0x2, f"ADD HL,DE failed: H should be 1, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x1, f"ADD HL,DE failed: C should be 1, got F={hex(actual_f)}"


@cocotb.test()
async def test_add_hl_hl_carry_only(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x29])  # ADD HL,HL
    await reset_cpu(dut)

    dut.reg_file.HL_reg.value = 0x8000
    dut.reg_file.AF_reg.value = 0x0000

    await do_cycles(dut, 2)

    actual_hl = dut.reg_file.HL_reg.value.integer
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F

    assert (
        actual_hl == 0x0000
    ), f"ADD HL,HL failed: expected HL=0x0000, got {hex(actual_hl)}"
    assert (
        actual_f & 0x4
    ) == 0x0, f"ADD HL,HL failed: N should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x2
    ) == 0x0, f"ADD HL,HL failed: H should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x1, f"ADD HL,HL failed: C should be 1, got F={hex(actual_f)}"


@cocotb.test()
async def test_add_hl_sp_halfcarry(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0x39])  # ADD HL,SP
    await reset_cpu(dut)

    dut.reg_file.HL_reg.value = 0x8FFF
    dut.reg_file.SP_reg.value = 0x0001
    dut.reg_file.AF_reg.value = 0x0000

    await do_cycles(dut, 2)

    actual_hl = dut.reg_file.HL_reg.value.integer
    actual_f = (dut.reg_file.AF_reg.value.integer >> 4) & 0x0F

    assert (
        actual_hl == 0x9000
    ), f"ADD HL,SP failed: expected HL=0x9000, got {hex(actual_hl)}"
    assert (
        actual_f & 0x4
    ) == 0x0, f"ADD HL,SP failed: N should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x2
    ) == 0x2, f"ADD HL,SP failed: H should be 1, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x0, f"ADD HL,SP failed: C should be 0, got F={hex(actual_f)}"
    assert (
        actual_f & 0x1
    ) == 0x0, f"ADD HL,SP failed: C should be 0, got F={hex(actual_f)}"


@cocotb.test()
async def test_push_bc(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xC5])  # PUSH BC
    await reset_cpu(dut)

    dut.reg_file.BC_reg.value = 0x1234
    dut.reg_file.SP_reg.value = 0xC010

    await do_cycles(dut, 4)

    sp = dut.reg_file.SP_reg.value.integer
    low = mem.data.get(0xC00E, 0)
    high = mem.data.get(0xC00F, 0)

    assert sp == 0xC00E, f"PUSH BC failed: expected SP=0xC00E, got {hex(sp)}"
    assert low == 0x34, f"PUSH BC failed: expected [0xC00E]=0x34, got {hex(low)}"
    assert high == 0x12, f"PUSH BC failed: expected [0xC00F]=0x12, got {hex(high)}"


@cocotb.test()
async def test_push_af(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xF5])  # PUSH AF
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x42B0
    dut.reg_file.SP_reg.value = 0xC100

    await do_cycles(dut, 4)

    sp = dut.reg_file.SP_reg.value.integer
    low = mem.data.get(0xC0FE, 0)
    high = mem.data.get(0xC0FF, 0)

    assert sp == 0xC0FE, f"PUSH AF failed: expected SP=0xC0FE, got {hex(sp)}"
    assert low == 0xB0, f"PUSH AF failed: expected [0xC0FE]=0xB0, got {hex(low)}"
    assert high == 0x42, f"PUSH AF failed: expected [0xC0FF]=0x42, got {hex(high)}"


@cocotb.test()
async def test_pop_de(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xD1], data={0xC000: 0x78, 0xC001: 0x56})  # POP DE
    await reset_cpu(dut)

    dut.reg_file.SP_reg.value = 0xC000
    dut.reg_file.DE_reg.value = 0x0000

    await do_cycles(dut, 3)

    de = dut.reg_file.DE_reg.value.integer
    sp = dut.reg_file.SP_reg.value.integer

    assert de == 0x5678, f"POP DE failed: expected DE=0x5678, got {hex(de)}"
    assert sp == 0xC002, f"POP DE failed: expected SP=0xC002, got {hex(sp)}"


@cocotb.test()
async def test_pop_hl(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xE1], data={0xBFFE: 0xCD, 0xBFFF: 0xAB})  # POP HL
    await reset_cpu(dut)

    dut.reg_file.SP_reg.value = 0xBFFE
    dut.reg_file.HL_reg.value = 0x0000

    await do_cycles(dut, 3)

    hl = dut.reg_file.HL_reg.value.integer
    sp = dut.reg_file.SP_reg.value.integer

    assert hl == 0xABCD, f"POP HL failed: expected HL=0xABCD, got {hex(hl)}"
    assert sp == 0xC000, f"POP HL failed: expected SP=0xC000, got {hex(sp)}"


@cocotb.test()
async def test_pop_af_masks_low_nibble_of_f(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xF1], data={0xC000: 0xFF, 0xC001: 0x12})  # POP AF
    await reset_cpu(dut)

    dut.reg_file.SP_reg.value = 0xC000
    dut.reg_file.AF_reg.value = 0x0000

    await do_cycles(dut, 3)

    af = dut.reg_file.AF_reg.value.integer
    a = (af >> 8) & 0xFF
    f = af & 0xFF
    sp = dut.reg_file.SP_reg.value.integer

    assert a == 0x12, f"POP AF failed: expected A=0x12, got {hex(a)}"
    assert f == 0xF0, f"POP AF failed: expected F lower nibble masked, got {hex(f)}"
    assert sp == 0xC002, f"POP AF failed: expected SP=0xC002, got {hex(sp)}"


@cocotb.test()
async def test_push_then_pop_roundtrip_bc_to_de(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xC5, 0xD1])  # PUSH BC; POP DE
    await reset_cpu(dut)

    dut.reg_file.BC_reg.value = 0x9A31
    dut.reg_file.DE_reg.value = 0x0000
    dut.reg_file.SP_reg.value = 0xC200

    await do_cycles(dut, 4)  # PUSH BC

    sp_mid = dut.reg_file.SP_reg.value.integer
    low_mid = mem.data.get(0xC1FE, 0)
    high_mid = mem.data.get(0xC1FF, 0)
    assert sp_mid == 0xC1FE, f"PUSH phase failed: expected SP=0xC1FE, got {hex(sp_mid)}"
    assert (
        low_mid == 0x31
    ), f"PUSH phase failed: expected [0xC1FE]=0x31, got {hex(low_mid)}"
    assert (
        high_mid == 0x9A
    ), f"PUSH phase failed: expected [0xC1FF]=0x9A, got {hex(high_mid)}"

    await do_cycles(dut, 3)  # POP DE

    de = dut.reg_file.DE_reg.value.integer
    sp = dut.reg_file.SP_reg.value.integer

    assert de == 0x9A31, f"PUSH/POP roundtrip failed: expected DE=0x9A31, got {hex(de)}"
    assert (
        sp == 0xC200
    ), f"PUSH/POP roundtrip failed: expected SP restored to 0xC200, got {hex(sp)}"


@cocotb.test()
async def test_ldh_a8_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xE0, 0x42])  # LDH (0xFF00+0x42),A
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0xAB00  # A=0xAB

    await do_cycles(dut, 3)

    actual = mem.data.get(0xFF42, 0)
    assert (
        actual == 0xAB
    ), f"LDH (a8),A failed: expected [0xFF42]=0xAB, got {hex(actual)}"


@cocotb.test()
async def test_ldh_a_ind_a8(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xF0, 0x80], data={0xFF80: 0x5E})  # LDH A,(0xFF00+0x80)
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x0000

    await do_cycles(dut, 3)

    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert actual_a == 0x5E, f"LDH A,(a8) failed: expected A=0x5E, got {hex(actual_a)}"


@cocotb.test()
async def test_ldh_c_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xE2])  # LDH (C),A  -> [0xFF00 + C] = A
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x7700  # A=0x77
    dut.reg_file.BC_reg.value = 0x0033  # C=0x33

    await do_cycles(dut, 2)

    actual = mem.data.get(0xFF33, 0)
    assert (
        actual == 0x77
    ), f"LDH (C),A failed: expected [0xFF33]=0x77, got {hex(actual)}"


@cocotb.test()
async def test_ldh_a_ind_c(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [0xF2], data={0xFF10: 0xC4})  # LDH A,(C)
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x0000
    dut.reg_file.BC_reg.value = 0x0010  # C=0x10

    await do_cycles(dut, 2)

    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert actual_a == 0xC4, f"LDH A,(C) failed: expected A=0xC4, got {hex(actual_a)}"


@cocotb.test()
async def test_ld_a16_ind_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    # EA 34 12 => LD [0x1234], A
    mem = CPUMemory(dut, [0xEA, 0x34, 0x12])
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x9B00  # A=0x9B

    await do_cycles(dut, 4)

    actual = mem.data.get(0x1234, 0)
    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert (
        actual == 0x9B
    ), f"LD [a16],A failed: expected [0x1234]=0x9B, got {hex(actual)}"
    assert (
        actual_a == 0x9B
    ), f"LD [a16],A failed: A should remain 0x9B, got {hex(actual_a)}"


@cocotb.test()
async def test_ld_a_ind_a16(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    # FA 78 56 => LD A, [0x5678]
    mem = CPUMemory(dut, [0xFA, 0x78, 0x56], data={0x5678: 0x3C})
    await reset_cpu(dut)

    dut.reg_file.AF_reg.value = 0x0000

    await do_cycles(dut, 4)

    actual_a = (dut.reg_file.AF_reg.value.integer >> 8) & 0xFF
    assert actual_a == 0x3C, f"LD A,[a16] failed: expected A=0x3C, got {hex(actual_a)}"


async def _run_rst_vector_case(dut, opcode: int, expected_vector: int):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [opcode, 0x00])
    await reset_cpu(dut)

    dut.reg_file.SP_reg.value = 0xBFFE

    await do_cycles(dut, 3)  # 4 cycles but check before IF

    actual_pc = dut.reg_file.PC_reg.value.integer
    actual_sp = dut.reg_file.SP_reg.value.integer
    stacked_pcl = mem.data.get(0xBFFC, 0)
    stacked_pch = mem.data.get(0xBFFD, 0)

    assert (
        actual_pc == expected_vector
    ), f"RST failed for opcode {hex(opcode)}: expected PC={hex(expected_vector)}, got {hex(actual_pc)}"
    assert (
        actual_sp == 0xBFFC
    ), f"RST failed for opcode {hex(opcode)}: expected SP=0xBFFC, got {hex(actual_sp)}"
    assert (
        stacked_pcl == 0x01
    ), f"RST failed for opcode {hex(opcode)}: expected stacked PCL=0x01, got {hex(stacked_pcl)}"
    assert (
        stacked_pch == 0x00
    ), f"RST failed for opcode {hex(opcode)}: expected stacked PCH=0x00, got {hex(stacked_pch)}"


@cocotb.test()
async def test_rst_00(dut):
    await _run_rst_vector_case(dut, 0xC7, 0x00)


@cocotb.test()
async def test_rst_08(dut):
    await _run_rst_vector_case(dut, 0xCF, 0x08)


@cocotb.test()
async def test_rst_10(dut):
    await _run_rst_vector_case(dut, 0xD7, 0x10)


@cocotb.test()
async def test_rst_18(dut):
    await _run_rst_vector_case(dut, 0xDF, 0x18)


@cocotb.test()
async def test_rst_20(dut):
    await _run_rst_vector_case(dut, 0xE7, 0x20)


@cocotb.test()
async def test_rst_28(dut):
    await _run_rst_vector_case(dut, 0xEF, 0x28)


@cocotb.test()
async def test_rst_30(dut):
    await _run_rst_vector_case(dut, 0xF7, 0x30)


@cocotb.test()
async def test_rst_38(dut):
    await _run_rst_vector_case(dut, 0xFF, 0x38)
