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
    assert actual == 0x42, f"LD A, (DE) failed: expected 0x42, got {hex(actual)}"
