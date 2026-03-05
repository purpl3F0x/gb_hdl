import gen_utils

def generate():
    out = [gen_utils.get_test_header()]
    
    # INC/DEC 16-bit
    for rr_idx, rr in enumerate(gen_utils.REGS_16):
        for op_idx, op in enumerate(["INC", "DEC"]):
            opcode = (0b00 << 6) | (rr_idx << 4) | (op_idx << 3) | 0b011
            expected_change = 1 if op == "INC" else -1
            expected_change &= 0xFFFF
            out.append(
                f"""
@cocotb.test()
async def test_{op.lower()}_16bit_{rr.lower()}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.{rr}_reg.value = 0x1000
    await do_cycles(dut,2)
    expected = (0x1000 + {expected_change}) & 0xFFFF
    actual = dut.reg_file.{rr}_reg.value.to_unsigned()
    assert actual == expected, f"{op} {rr} failed: expected {{hex(expected)}}, got {{hex(actual)}}"
"""
            )

    # INC/DEC 8-bit
    for r_idx, r in enumerate(gen_utils.REGS_8):
        for op_idx, op in enumerate(["INC", "DEC"]):
            opcode = (0b00 << 6) | (r_idx << 3) | (op_idx << 0) | 0b100
            expected_change = 1 if op == "INC" else -1
            if r == "(HL)":
                val = 0x42
                expected = (val + expected_change) & 0xFF
                out.append(
                    f"""
@cocotb.test()
async def test_{op.lower()}_8bit_hl_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00], data={{0x8000: {hex(val)}}})
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut,3)
    actual = mem.data.get(0x8000, 0)
    assert actual == {hex(expected)}, f"{op} (HL) failed: expected {hex(expected)}, got {{hex(actual)}}"
"""
                )
            else:
                reg16, shift = gen_utils.get_reg_access(r)
                val = 0x10
                expected = (val + expected_change) & 0xFF
                out.append(
                    f"""
@cocotb.test()
async def test_{op.lower()}_8bit_{r.lower()}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.{reg16}_reg.value = {hex(val << shift)}
    await do_cycles(dut,1)
    actual = (dut.reg_file.{reg16}_reg.value.to_unsigned() >> {shift}) & 0xFF
    assert actual == {hex(expected)}, f"{op} {r} failed: expected {hex(expected)}, got {{hex(actual)}}"
"""
                )

    with open("test_inc_dec.py", "w") as f:
        f.write("".join(out))

if __name__ == "__main__":
    generate()
