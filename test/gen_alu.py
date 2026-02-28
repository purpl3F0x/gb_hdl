import gen_utils

def generate():
    out = [gen_utils.get_test_header()]
    
    # ALU A, r
    for op_idx, op in enumerate(gen_utils.ALU_OPS):
        for r_idx, r in enumerate(gen_utils.REGS_8):
            opcode = (0b10 << 6) | (op_idx << 3) | r_idx
            if op == "ADD":
                if r == "A":
                    variants = [
                        ("normal", 0x42, 0x42, 0, 0x84, 0x00),
                        ("half_carry", 0x0F, 0x0F, 0, 0x1E, 0x20),
                        ("carry", 0xF0, 0xF0, 0, 0xE0, 0x10),
                        ("zero", 0x00, 0x00, 0, 0x00, 0x80),
                    ]
                else:
                    variants = [
                        ("normal", 0x42, 0x01, 0, 0x43, 0x00),
                        ("half_carry", 0x42, 0x0F, 0, 0x51, 0x20),
                        ("carry", 0xF0, 0x11, 0, 0x01, 0x10),
                        ("zero", 0x00, 0x00, 0, 0x00, 0x80),
                    ]
            elif op == "ADC":
                if r == "A":
                    variants = [
                        ("with_carry", 0x42, 0x42, 0x10, 0x85, 0x00),
                        ("without_carry", 0x42, 0x42, 0x00, 0x84, 0x00),
                    ]
                else:
                    variants = [
                        ("with_carry", 0x42, 0x01, 0x10, 0x44, 0x00),
                        ("without_carry", 0x42, 0x01, 0x00, 0x43, 0x00),
                    ]
            else:
                a_val = 0x50
                b_val = 0x20
                if r == "A":
                    b_val = a_val
                expected = gen_utils.alu_op_expected(op, a_val, b_val)
                variants = [("", a_val, b_val, 0, expected, None)]

            for v_name, a_val, b_val, flag_in, expected_a, expected_f in variants:
                test_name_suffix = f"_{v_name}" if v_name else ""

                if r == "(HL)":
                    out.append(
                        f"""
@cocotb.test()
async def test_alu_{op.lower()}_a_hl_ind{test_name_suffix}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00], data={{0x8000: {hex(b_val)}}})
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = ({hex(a_val)} << 8) | {hex(flag_in)}
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut,2)
    actual_a = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    assert actual_a == {hex(expected_a)}, f"{op} A, (HL) {v_name} failed: expected A={hex(expected_a)}, got {{hex(actual_a)}}"
"""
                    )
                    if expected_f is not None:
                        out.append(
                            f"    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F\n"
                        )
                        out.append(
                            f'    assert actual_f == {hex(expected_f >> 4)}, f"{op} A, (HL) {v_name} failed: expected F={hex(expected_f >> 4)}, got {{hex(actual_f)}}"\n'
                        )
                else:
                    reg16, shift = gen_utils.get_reg_access(r)
                    out.append(
                        f"""
@cocotb.test()
async def test_alu_{op.lower()}_a_{r.lower()}{test_name_suffix}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = ({hex(a_val)} << 8) | {hex(flag_in)}
    if "{r}" != "A":
        dut.reg_file.{reg16}_reg.value = ({hex(b_val)} << {shift})
    await do_cycles(dut,1)
    actual_a = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    assert actual_a == {hex(expected_a)}, f"{op} A, {r} {v_name} failed: expected A={hex(expected_a)}, got {{hex(actual_a)}}"
"""
                    )
                    if expected_f is not None:
                        out.append(
                            f"    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F\n"
                        )
                        out.append(
                            f'    assert actual_f == {hex(expected_f >> 4)}, f"{op} A, {r} {v_name} failed: expected F={hex(expected_f >> 4)}, got {{hex(actual_f)}}"\n'
                        )

    # ALU A, n
    for op_idx, op in enumerate(gen_utils.ALU_OPS):
        opcode = (0b11 << 6) | (op_idx << 3) | 0b110
        a_val = 0x50
        n_val = 0x42
        expected = gen_utils.alu_op_expected(op, a_val, n_val)
        out.append(
            f"""
@cocotb.test()
async def test_alu_imm_{op.lower()}_a_n(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [{hex(opcode)}, {hex(n_val)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(a_val << 8)}
    await do_cycles(dut,2)
    actual = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    assert actual == {hex(expected)}, f"{op} A, n failed: expected {hex(expected)}, got {{hex(actual)}}"
"""
        )

    with open("test_alu.py", "w") as f:
        f.write("".join(out))

if __name__ == "__main__":
    generate()
