import gen_utils

CB_OPS = ["RLC", "RRC", "RL", "RR", "SLA", "SRA", "SWAP", "SRL"]
BIT_OPCODE_BASE = 0x40
RES_OPCODE_BASE = 0x80
SET_OPCODE_BASE = 0xC0


def cb_op_expected(op, val, flags_in_c):
    c = flags_in_c
    z, n, h, out_c = 0, 0, 0, 0
    res = val
    if op == "RLC":
        out_c = (val >> 7) & 1
        res = ((val << 1) | out_c) & 0xFF
    elif op == "RRC":
        out_c = val & 1
        res = ((val >> 1) | (out_c << 7)) & 0xFF
    elif op == "RL":
        out_c = (val >> 7) & 1
        res = ((val << 1) | c) & 0xFF
    elif op == "RR":
        out_c = val & 1
        res = ((val >> 1) | (c << 7)) & 0xFF
    elif op == "SLA":
        out_c = (val >> 7) & 1
        res = (val << 1) & 0xFF
    elif op == "SRA":
        out_c = val & 1
        res = (val >> 1) | (val & 0x80)
    elif op == "SWAP":
        res = ((val & 0x0F) << 4) | ((val & 0xF0) >> 4)
        out_c = 0
    elif op == "SRL":
        out_c = val & 1
        res = (val >> 1) & 0xFF

    z = 1 if res == 0 else 0
    flags = (z << 7) | (n << 6) | (h << 5) | (out_c << 4)
    return res, flags


def generate():
    out = [gen_utils.get_test_header()]

    for op_idx, op in enumerate(CB_OPS):
        for r_idx, r in enumerate(gen_utils.REGS_8):
            opcode_cb = (op_idx << 3) | r_idx

            # Base test cases
            test_cases = []  # (name, val, flag_in_c)

            if op in ["RL", "RR"]:
                test_cases.append(("c0", 0x81, 0))
                test_cases.append(("c1", 0x81, 1))
            elif op == "SWAP":
                test_cases.append(("normal", 0x35, 0))
                test_cases.append(("zero", 0x00, 0))
            else:
                test_cases.append(("carry0", 0x01, 0))
                test_cases.append(("carry1", 0x80, 0))
                test_cases.append(("zero", 0x00, 0))

            for v_name, val, flag_in_c in test_cases:
                expected_res, expected_f = cb_op_expected(op, val, flag_in_c)
                flag_in = flag_in_c << 4

                test_name = f"test_cb_{op.lower()}_{r.lower().replace('(','').replace(')','')}_{v_name}"

                if r == "(HL)":
                    out.append(
                        f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00], data={{0x8000: {hex(val)}}})
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut, 4) # CB (1) + (HL) read (1) + ALU (1) + (HL) write (1) = 4 cycles total? 
    actual_res = mem.data[0x8000]
    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F
    assert actual_res == {hex(expected_res)}, f"{op} (HL) failed: expected {hex(expected_res)}, got {{hex(actual_res)}}"
    assert actual_f == {hex(expected_f >> 4)}, f"{op} (HL) flags failed: expected {hex(expected_f >> 4)}, got {{hex(actual_f)}}"
"""
                    )
                else:
                    reg16, shift = gen_utils.get_reg_access(r)
                    out.append(
                        f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    if "{r}" != "A":
        dut.reg_file.{reg16}_reg.value = {hex(val)} << {shift}
    else:
        dut.reg_file.AF_reg.value = ({hex(val)} << 8) | {hex(flag_in)}
        
    await do_cycles(dut, 2) # 1 for CB prefix, 1 for opcode
    
    if "{r}" == "A":
        actual_res = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    else:
        actual_res = (dut.reg_file.{reg16}_reg.value.to_unsigned() >> {shift}) & 0xFF
        
    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F
    assert actual_res == {hex(expected_res)}, f"{op} {r} failed: expected {hex(expected_res)}, got {{hex(actual_res)}}"
    assert actual_f == {hex(expected_f >> 4)}, f"{op} {r} flags failed: expected {hex(expected_f >> 4)}, got {{hex(actual_f)}}"
"""
                    )

    # BIT b, r and BIT b, (HL)
    bit_indices = range(8)
    for bit_idx in bit_indices:
        for r_idx, r in enumerate(gen_utils.REGS_8):
            opcode_cb = BIT_OPCODE_BASE | (bit_idx << 3) | r_idx

            # (name, val, carry_in)
            test_cases = [
                ("bit_clear_c0", 0x00, 0),
                ("bit_set_c1", (1 << bit_idx) & 0xFF, 1),
            ]

            for v_name, val, carry_in in test_cases:
                expected_z = 1 if ((val >> bit_idx) & 1) == 0 else 0
                flag_in = carry_in << 4

                test_name = f"test_cb_bit_b{bit_idx}_{r.lower().replace('(', '').replace(')', '')}_{v_name}"

                if r == "(HL)":
                    out.append(
                        f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00], data={{0x8000: {hex(val)}}})
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut, 3)
    actual_mem = mem.data[0x8000]
    actual_n = (dut.reg_file.AF_reg.value.to_unsigned() >> 6) & 0x01
    actual_h = (dut.reg_file.AF_reg.value.to_unsigned() >> 5) & 0x01
    actual_z = (dut.reg_file.AF_reg.value.to_unsigned() >> 7) & 0x01
    assert actual_mem == {hex(val)}, f"BIT {bit_idx}, (HL) should not modify memory: expected {hex(val)}, got {{hex(actual_mem)}}"
    assert actual_z == {expected_z}, f"BIT {bit_idx}, (HL) Z failed: expected {expected_z}, got {{actual_z}}"
    assert actual_n == 0, f"BIT {bit_idx}, (HL) N failed: expected 0, got {{actual_n}}"
    assert actual_h == 1, f"BIT {bit_idx}, (HL) H failed: expected 1, got {{actual_h}}"
"""
                    )
                else:
                    reg16, shift = gen_utils.get_reg_access(r)
                    out.append(
                        f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    if "{r}" != "A":
        dut.reg_file.{reg16}_reg.value = {hex(val)} << {shift}
    else:
        dut.reg_file.AF_reg.value = ({hex(val)} << 8) | {hex(flag_in)}

    await do_cycles(dut, 2)

    if "{r}" == "A":
        actual_res = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    else:
        actual_res = (dut.reg_file.{reg16}_reg.value.to_unsigned() >> {shift}) & 0xFF

    actual_n = (dut.reg_file.AF_reg.value.to_unsigned() >> 6) & 0x01
    actual_h = (dut.reg_file.AF_reg.value.to_unsigned() >> 5) & 0x01
    actual_z = (dut.reg_file.AF_reg.value.to_unsigned() >> 7) & 0x01
    assert actual_res == {hex(val)}, f"BIT {bit_idx}, {r} should not modify operand: expected {hex(val)}, got {{hex(actual_res)}}"
    assert actual_z == {expected_z}, f"BIT {bit_idx}, {r} Z failed: expected {expected_z}, got {{actual_z}}"
    assert actual_n == 0, f"BIT {bit_idx}, {r} N failed: expected 0, got {{actual_n}}"
    assert actual_h == 1, f"BIT {bit_idx}, {r} H failed: expected 1, got {{actual_h}}"
"""
                    )

    # RES/SET b, r and RES/SET b, (HL)
    bitops = [
        ("res", RES_OPCODE_BASE, lambda value, bit: value & ~(1 << bit)),
        ("set", SET_OPCODE_BASE, lambda value, bit: value | (1 << bit)),
    ]

    for op_name, opcode_base, transform in bitops:
        for bit_idx in bit_indices:
            for r_idx, r in enumerate(gen_utils.REGS_8):
                opcode_cb = opcode_base | (bit_idx << 3) | r_idx

                base_val = 0xA5
                # (name, input_value) - test both not-set and set input bit
                test_cases = [
                    ("bit_clear", base_val & ~(1 << bit_idx)),
                    ("bit_set", base_val | (1 << bit_idx)),
                ]

                for v_name, val in test_cases:
                    expected_res = transform(val, bit_idx) & 0xFF
                    flag_in_nibble = 0xB
                    flag_in = flag_in_nibble << 4

                    test_name = f"test_cb_{op_name}_b{bit_idx}_{r.lower().replace('(', '').replace(')', '')}_{v_name}"

                    if r == "(HL)":
                        out.append(
                            f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00], data={{0x8000: {hex(val)}}})
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    dut.reg_file.HL_reg.value = 0x8000
    await do_cycles(dut, 4)
    actual_mem = mem.data[0x8000]
    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F
    assert actual_mem == {hex(expected_res)}, f"{op_name.upper()} {bit_idx}, (HL) result failed: expected {hex(expected_res)}, got {{hex(actual_mem)}}"
    assert actual_f == {hex(flag_in_nibble)}, f"{op_name.upper()} {bit_idx}, (HL) flags failed: expected {hex(flag_in_nibble)}, got {{hex(actual_f)}}"
"""
                        )
                    else:
                        reg16, shift = gen_utils.get_reg_access(r)
                        out.append(
                            f"""
@cocotb.test()
async def {test_name}(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    mem = CPUMemory(dut, [0xCB, {hex(opcode_cb)}, 0x00])
    await reset_cpu(dut)
    dut.reg_file.AF_reg.value = {hex(flag_in)}
    if "{r}" != "A":
        dut.reg_file.{reg16}_reg.value = {hex(val)} << {shift}
    else:
        dut.reg_file.AF_reg.value = ({hex(val)} << 8) | {hex(flag_in)}

    await do_cycles(dut, 2)

    if "{r}" == "A":
        actual_res = (dut.reg_file.AF_reg.value.to_unsigned() >> 8) & 0xFF
    else:
        actual_res = (dut.reg_file.{reg16}_reg.value.to_unsigned() >> {shift}) & 0xFF

    actual_f = (dut.reg_file.AF_reg.value.to_unsigned() >> 4) & 0x0F
    assert actual_res == {hex(expected_res)}, f"{op_name.upper()} {bit_idx}, {r} result failed: expected {hex(expected_res)}, got {{hex(actual_res)}}"
    assert actual_f == {hex(flag_in_nibble)}, f"{op_name.upper()} {bit_idx}, {r} flags failed: expected {hex(flag_in_nibble)}, got {{hex(actual_f)}}"
"""
                        )

    with open("test_cb.py", "w") as f:
        f.write("".join(out))


if __name__ == "__main__":
    generate()
