import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

DIV_REG = 0xFF04
TIMA_REG = 0xFF05
TMA_REG = 0xFF06
TAC_REG = 0xFF07

TAC_FREQ_TO_PERIOD = {
    0b00: 1024,
    0b01: 16,
    0b10: 64,
    0b11: 256,
}

CLK_PERIOD_NS = 40
CLK4_PERIOD_NS = CLK_PERIOD_NS // 4


def start_timer_clocks(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_4, CLK4_PERIOD_NS, unit="ns").start())


async def reset_dut(dut):
    dut.addr.value = 0
    dut.wdata.value = 0
    dut.we.value = 0
    dut.re.value = 0
    dut.stop.value = 0
    dut.timer_irq_ack.value = 0
    dut.rst.value = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def write_reg(dut, addr, value):
    dut.addr.value = addr
    dut.wdata.value = value
    dut.we.value = 1
    dut.re.value = 0

    await RisingEdge(dut.clk)

    dut.we.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0


async def read_reg(dut, addr):
    dut.addr.value = addr
    dut.re.value = 1
    dut.we.value = 0

    await Timer(1, unit="ns")
    value = int(dut.rdata.value)

    dut.re.value = 0
    dut.addr.value = 0

    return value


async def wait_tima_increment(dut, timeout_cycles):
    start = await read_reg(dut, TIMA_REG)

    for elapsed in range(1, timeout_cycles + 1):
        await RisingEdge(dut.clk_4)
        current = await read_reg(dut, TIMA_REG)
        if current == ((start + 1) & 0xFF):
            return elapsed

    raise AssertionError(f"TIMA did not increment within {timeout_cycles} cycles")


@cocotb.test()
async def test_div_runs(dut):
    start_timer_clocks(dut)
    await reset_dut(dut)

    div0 = await read_reg(dut, DIV_REG)

    await RisingEdge(dut.clk_4)
    for _ in range(255):
        await RisingEdge(dut.clk_4)

    div1 = await read_reg(dut, DIV_REG)

    await RisingEdge(dut.clk_4)
    for _ in range(255):
        await RisingEdge(dut.clk_4)

    div2 = await read_reg(dut, DIV_REG)

    assert div1 == (
        (div0 + 1) & 0xFF
    ), f"DIV[15:8] should increment by 1 every 256 cycles: start={div0:#04x}, got={div1:#04x}"
    assert div2 == (
        (div1 + 1) & 0xFF
    ), f"DIV[15:8] should keep incrementing every 256 cycles: prev={div1:#04x}, got={div2:#04x}"


@cocotb.test()
async def test_div_reset_rst_and_stop(dut):
    start_timer_clocks(dut)
    await reset_dut(dut)

    for _ in range(300):
        await RisingEdge(dut.clk_4)
    div_before_reset = await read_reg(dut, DIV_REG)
    assert div_before_reset != 0, "DIV should become non-zero after running"

    await write_reg(dut, DIV_REG, 0xAB)
    div_after_write_reset = await read_reg(dut, DIV_REG)
    assert div_after_write_reset == 0, "Writing FF04 must reset DIV to 0"

    dut.stop.value = 1
    for _ in range(8):
        await RisingEdge(dut.clk_4)
    div_while_stop = await read_reg(dut, DIV_REG)
    assert div_while_stop == 0, "DIV must stay 0 while STOP is asserted"

    dut.stop.value = 0
    await RisingEdge(dut.clk_4)
    for _ in range(300):
        await RisingEdge(dut.clk_4)
    div_after_stop = await read_reg(dut, DIV_REG)
    assert div_after_stop != 0, "DIV should resume counting after STOP deasserts"

    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    div_after_rst = await read_reg(dut, DIV_REG)
    assert div_after_rst == 0, "DIV must reset to 0 during reset"


@cocotb.test()
async def test_tima_all_4_speeds(dut):
    start_timer_clocks(dut)

    for freq_sel, period in TAC_FREQ_TO_PERIOD.items():
        await reset_dut(dut)

        await write_reg(dut, TIMA_REG, 0x00)
        await write_reg(dut, DIV_REG, 0x00)

        tac_value = 0b100 | freq_sel
        await write_reg(dut, TAC_REG, tac_value)

        _ = await wait_tima_increment(dut, timeout_cycles=period + 2)

        for _ in range(3):
            measured = await wait_tima_increment(dut, timeout_cycles=period + 2)
            assert (
                measured == period
            ), f"TIMA period mismatch for TAC={freq_sel:02b}: expected {period} cycles, got {measured}"


@cocotb.test()
async def test_tima_overflow_reload_and_irq_delayed_one_cycle(dut):
    start_timer_clocks(dut)
    await reset_dut(dut)

    TMA_VALUE = 0x23
    dut.uut.DIV.value = 0x0000
    dut.uut.TIMA.value = 0xFE
    dut.uut.TMA.value = TMA_VALUE
    dut.uut.TAC.value = 0b0101
    dut.uut.bit_delay.value = 0

    [await RisingEdge(dut.clk) for _ in range(5)]
    tima = dut.uut.TIMA.value.integer
    irq = int(dut.timer_irq.value)
    assert (
        tima == 0xFF
    ), f"TIMA should not increment on the first edge: expected 0xFE, got {tima:#04x}"
    assert (
        irq == 0
    ), f"IRQ should not be requested on the first edge: expected 0, got {irq}"

    [await RisingEdge(dut.clk) for _ in range(4)]
    tima = dut.uut.TIMA.value.integer
    irq = int(dut.timer_irq.value)
    assert (
        tima == 0x00
    ), f"TIMA should reload to TMA on overflow: expected 0x23, got {tima:#04x}"
    assert irq == 0, f"IRQ should be requested on overflow: expected 0, got {irq}"

    [await RisingEdge(dut.clk) for _ in range(4)]
    tima = dut.uut.TIMA.value.integer
    irq = int(dut.timer_irq.value)
    assert (
        tima == TMA_VALUE
    ), f"TIMA should increment to 0x01 after reload: expected {TMA_VALUE:#04x}, got {tima:#04x}"

    # ACK
    dut.timer_irq_ack.value = 1
    await RisingEdge(dut.clk)
    dut.timer_irq_ack.value = 0
    await RisingEdge(dut.clk)
    irq = int(dut.timer_irq.value)
    assert irq == 0, f"IRQ should be cleared after ACK: expected 0, got {irq}"


def test_timer_pytest():
    sim = os.getenv("SIM", "verilator")

    proj_path = Path(__file__).resolve().parents[2]
    sources = [
        proj_path / "rtl" / "boy_pkg.sv",
        proj_path / "rtl" / "timer.sv",
        proj_path / "test" / "timer_test" / "timer_cocotb_dut.sv",
    ]

    runner = get_runner(sim)
    build_args = ["-Wall"]
    if sim == "icarus":
        build_args = ["-g2012", "-Wall"]
    elif sim == "verilator":
        build_args += ["-Wno-DECLFILENAME", "-Wno-IMPORTSTAR"]

    runner.build(
        sources=sources,
        hdl_toplevel="timer_cocotb_dut",
        always=True,
        waves=False,
        build_args=build_args,
    )

    runner.test(
        hdl_toplevel="timer_cocotb_dut",
        test_module=Path(__file__).stem,
        waves=False,
        gui=False,
    )


if __name__ == "__main__":
    test_timer_pytest()
