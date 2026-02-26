import gen_utils

def generate():
    out = [gen_utils.get_test_header()]
    
    # LD r, n8
    for r_idx, r in enumerate(gen_utils.REGS_8):
        opcode = (0b00 << 6) | (r_idx << 3) | 0b110
        val = 0x42
        if r == "(HL)":
            out.append(
                f"""
@cocotb.test()
async def test_ld_hl_ind_n8(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, {hex(val)}])
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut, 3)
    actual = mem.data.get(0x8000, 0)
    assert actual == {hex(val)}, f"LD (HL), n8 failed: expected {hex(val)}, got {{hex(actual)}}"
"""
            )
        else:
            reg16, shift = gen_utils.get_reg_access(r)
            out.append(
                f"""
@cocotb.test()
async def test_ld_{r.lower()}_n8(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, {hex(val)}])
    await reset_cpu(dut)
    dut.reg_file.{reg16}_reg.value = 0
    await do_cycles(dut, 2)
    actual = (dut.reg_file.{reg16}_reg.value.integer >> {shift}) & 0xFF
    assert actual == {hex(val)}, f"LD {r}, n8 failed: expected {hex(val)}, got {{hex(actual)}}"
"""
            )

    # LD 16-bit immediate
    for rr_idx, rr in enumerate(gen_utils.REGS_16):
        opcode = (0b00 << 6) | (rr_idx << 4) | 0b0001
        out.append(
            f"""
@cocotb.test()
async def test_ld_16bit_{rr.lower()}_n16(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x34, 0x12])
    await reset_cpu(dut)
    await do_cycles(dut, 3)
    actual = dut.reg_file.{rr}_reg.value.integer
    assert actual == 0x1234, f"LD {rr}, n16 failed: expected 0x1234, got {{hex(actual)}}"
"""
        )

    # LD r, r'
    for r1_idx, r1 in enumerate(gen_utils.REGS_8):
        for r2_idx, r2 in enumerate(gen_utils.REGS_8):
            if r1 == "(HL)" and r2 == "(HL)":
                continue
            opcode = (0b01 << 6) | (r1_idx << 3) | r2_idx

            if r1 == "(HL)":  # LD (HL), r
                reg16, shift = gen_utils.get_reg_access(r2)
                out.append(
                    f"""
@cocotb.test()
async def test_ld_hl_ind_{r2.lower()}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = {"0x8000" if reg16 != "HL" else "0x8042"}
    { f"dut.reg_file.{reg16}_reg.value = {hex(0x55 << shift)}" if reg16 != "HL" else "" }
    await do_cycles(dut,2)
    actual = mem.data.get({"0x8000" if reg16 != "HL" else "0x8042"}, 0)
    assert actual == {0x55 if reg16 != "HL" else hex((0x8042 >> shift) & 0xFF)}, f"LD (HL), {r2} failed: expected {0x55 if reg16 != "HL" else hex((0x8042 >> shift) & 0xFF)}, got {{hex(actual)}}"
"""
                )
            elif r2 == "(HL)":  # LD r, (HL)
                reg16, shift = gen_utils.get_reg_access(r1)
                out.append(
                    f"""
@cocotb.test()
async def test_ld_{r1.lower()}_hl_ind(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00], data={{0x8000: 0x99}})
    await reset_cpu(dut)
    dut.reg_file.HL_reg.value = 0x8000
    { f"dut.reg_file.{reg16}_reg.value = {hex(0x55 << shift)}" if reg16 != "HL" else "" }
    await do_cycles(dut,2)
    actual = (dut.reg_file.{reg16}_reg.value.integer >> {shift}) & 0xFF
    assert actual == 0x99, f"LD {r1}, (HL) failed: expected 0x99, got {{hex(actual)}}"
"""
                )
            else:  # LD r, r'
                reg16_1, shift1 = gen_utils.get_reg_access(r1)
                reg16_2, shift2 = gen_utils.get_reg_access(r2)
                out.append(
                    f"""
@cocotb.test()
async def test_ld_{r1.lower()}_{r2.lower()}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00])
    await reset_cpu(dut)
    val2 = 0x33
    dut.reg_file.{reg16_1}_reg.value = 0
    if "{r1}" != "{r2}": 
        dut.reg_file.{reg16_2}_reg.value = (val2 << {shift2})
    else:
        dut.reg_file.{reg16_1}_reg.value = (val2 << {shift1})
    await do_cycles(dut,1)
    actual = (dut.reg_file.{reg16_1}_reg.value.integer >> {shift1}) & 0xFF
    assert actual == val2, f"LD {r1}, {r2} failed: expected {{hex(val2)}}, got {{hex(actual)}}"
"""
                )

    with open("test_loads.py", "w") as f:
        f.write("".join(out))

if __name__ == "__main__":
    generate()
