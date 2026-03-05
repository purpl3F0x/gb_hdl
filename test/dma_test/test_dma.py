import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb_tools.runner import get_runner


@cocotb.test()
async def test_dma_single_transfer_counts_160_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.we.value = 0
    dut.re.value = 0
    dut.din.value = 0
    dut.rst.value = 1

    # Reset
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    BASE_ADDR = 0x42
    dut.din.value = BASE_ADDR
    dut.we.value = 1
    await RisingEdge(dut.clk)

    dut.we.value = 1  # try to trigger new dma transfer immediately, should be ignored
    dut.din.value = 0

    for expected in range(-1, 160):
        await RisingEdge(dut.clk)

        # try to trigger new dma transfer during active transfer, should be ignored
        if expected in [-1, 10, 50, 100]:  # arbitrary cycles during active transfer
            dut.we.value = 1
            dut.din.value = 0x99
        else:
            dut.we.value = 0
            dut.din.value = 0
        if expected == -1:
            continue

        assert int(dut.dma_active.value) == 1, (
            f"DMA should be active during cycle {expected}, "
            f"got dma_active={int(dut.dma_active.value)}"
        )

        observed = int(dut.dout.value)
        assert observed == expected, (
            f"DMA dout mismatch at transfer cycle {expected}: "
            f"expected {expected}, got {observed}"
        )

    await RisingEdge(dut.clk)
    assert int(dut.dma_active.value) == 0, "DMA should deassert after 160 bytes"


def test_dma_single_transfer_pytest():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parents[2]
    sources = [
        proj_path / "rtl" / "boy_pkg.sv",
        proj_path / "rtl" / "dma.sv",
    ]

    runner = get_runner(sim)
    build_args = ["-Wall"]
    if sim == "icarus":
        build_args = ["-g2012", "-Wall"]

    runner.build(
        sources=sources,
        hdl_toplevel="dma",
        always=False,
        waves=True,
        build_args=build_args,
    )

    runner.test(
        hdl_toplevel="dma", test_module=Path(__file__).stem, waves=True, gui=False
    )


if __name__ == "__main__":
    test_dma_single_transfer_pytest()
