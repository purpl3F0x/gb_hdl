import cocotb
from cocotb.triggers import RisingEdge, FallingEdge


class CPUMemory:
    def __init__(self, dut, program, data=None):
        self.dut = dut
        self.program = program
        self.data = data if data is not None else {}
        self._coro = cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await FallingEdge(self.dut.clk)

            if self.dut.rd_en.value == 1:
                try:
                    addr = self.dut.addr_out.value.to_unsigned()
                    if addr < len(self.program):
                        self.dut.data_in.value = self.program[addr]
                    else:
                        self.dut.data_in.value = self.data.get(addr, 0)
                except ValueError:
                    self.dut.data_in.value = 0
            elif self.dut.wr_en.value == 1:
                try:
                    addr = self.dut.addr_out.value.to_unsigned()
                    self.data[addr] = self.dut.data_out.value.to_unsigned()
                except ValueError:
                    pass


async def reset_cpu(dut):
    dut.rst.value = 1
    dut.data_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def do_cycles(dut, c: int):
    for _ in range(c):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
