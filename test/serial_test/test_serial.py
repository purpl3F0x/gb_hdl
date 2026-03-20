import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb_tools.runner import get_runner

CLK_PERIOD_NS = 40
CLK4_PERIOD_NS = CLK_PERIOD_NS // 4


def start_serial_clocks(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_4, CLK4_PERIOD_NS, unit="ns").start())


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

    await RisingEdge(dut.clk_4)
    value = int(dut.rdata.value)

    dut.re.value = 0
    dut.addr.value = 0

    return value


async def reset_dut(dut):
    dut.addr.value = 0
    dut.wdata.value = 0
    dut.we.value = 0
    dut.re.value = 0
    dut.serial_irq_ack.value = 0
    dut.si.value = 1
    dut.sck_in.value = 0
    dut.rst.value = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_serial_master_internal_clock_simple(dut):
    start_serial_clocks(dut)
    await reset_dut(dut)

    sc_idle = await read_reg(dut, 0)
    assert sc_idle == 0x7E, f"SC should be idle after reset, got {sc_idle:#04x}"

    tx_data = 0xA5
    tx_expected_bits = [int(bit) for bit in f"{tx_data:08b}"]

    rx_bits = [0, 1, 1, 0, 1, 0, 1, 1]
    rx_expected = int("".join(str(bit) for bit in rx_bits), 2)

    await write_reg(dut, 1, tx_data)  # SB (FF01)
    await write_reg(dut, 0, 0x81)  # SC (FF02): start + internal clock

    await RisingEdge(dut.clk_4)
    assert int(dut.sck_out.value) in (0, 1), "SCK should be driven in master mode"
    assert int(dut.uut.sc_en.value) == 1, "Transfer should be active after start write"

    observed_tx_bits = []
    for bit_index in range(8):
        await FallingEdge(dut.sck_out)
        if bit_index < 7:
            dut.si.value = rx_bits[bit_index]

        await RisingEdge(dut.sck_out)
        observed_tx_bits.append(int(dut.so.value))

    assert (
        observed_tx_bits == tx_expected_bits
    ), f"SO bits mismatch: expected {tx_expected_bits}, got {observed_tx_bits}"

    await RisingEdge(dut.clk)

    assert (
        int(dut.serial_irq.value) == 1
    ), "Serial IRQ should assert after 8 transferred bits"
    assert (
        int(dut.uut.sc_en.value) == 0
    ), "Transfer enable should clear when transfer is complete"
    assert (
        int(dut.uut.sb.value) == rx_expected
    ), f"SB mismatch after transfer: expected {rx_expected:#04x}, got {int(dut.uut.sb.value):#04x}"
    assert int(dut.sck_out.value) == 1, "SCK should return high in idle"

    dut.serial_irq_ack.value = 1
    await RisingEdge(dut.clk_4)
    dut.serial_irq_ack.value = 0
    await RisingEdge(dut.clk_4)

    assert int(dut.serial_irq.value) == 0, "Serial IRQ should clear after ACK"


@cocotb.test()
async def test_serial_master_internal_clock_send_hello(dut):
    start_serial_clocks(dut)
    await reset_dut(dut)

    message = b"hello"
    observed_tx_bytes = []

    for tx_data in message:
        await write_reg(dut, 1, tx_data)  # SB (FF01)
        await write_reg(dut, 0, 0x81)  # SC (FF02): start + internal clock

        await RisingEdge(dut.clk_4)
        assert (
            int(dut.uut.sc_en.value) == 1
        ), "Transfer should be active after start write"

        observed_tx_bits = []
        for _ in range(8):
            await FallingEdge(dut.sck_out)
            dut.si.value = 1

            await RisingEdge(dut.sck_out)
            observed_tx_bits.append(int(dut.so.value))

        observed_tx_byte = int("".join(str(bit) for bit in observed_tx_bits), 2)
        observed_tx_bytes.append(observed_tx_byte)

        await RisingEdge(dut.clk)
        assert (
            int(dut.serial_irq.value) == 1
        ), "Serial IRQ should assert after each transferred byte"

        dut.serial_irq_ack.value = 1
        await RisingEdge(dut.clk_4)
        dut.serial_irq_ack.value = 0
        await RisingEdge(dut.clk_4)

        assert int(dut.serial_irq.value) == 0, "Serial IRQ should clear after ACK"

    assert (
        bytes(observed_tx_bytes) == message
    ), f"Transmitted bytes mismatch: expected {message!r}, got {bytes(observed_tx_bytes)!r}"


def test_serial_pytest():
    sim = os.getenv("SIM", "verilator")
    waves = os.getenv("WAVES", "0") == "1"

    proj_path = Path(__file__).resolve().parents[2]
    sources = [
        proj_path / "rtl" / "boy_pkg.sv",
        proj_path / "rtl" / "serial.sv",
        proj_path / "test" / "serial_test" / "serial_cocotb_dut.sv",
    ]

    runner = get_runner(sim)
    build_args = ["-Wall"]
    if sim == "icarus":
        build_args += ["-g2012"]
    elif sim == "verilator":
        build_args += ["-Wno-fatal"]

    runner.build(
        sources=sources,
        hdl_toplevel="serial_cocotb_dut",
        always=False,
        waves=waves,
        build_args=build_args,
    )

    runner.test(
        hdl_toplevel="serial_cocotb_dut",
        test_module=Path(__file__).stem,
        waves=waves,
        gui=False,
    )


if __name__ == "__main__":
    test_serial_pytest()
