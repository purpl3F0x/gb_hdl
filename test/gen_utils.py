REGS_8 = ["B", "C", "D", "E", "H", "L", "(HL)", "A"]
REGS_16 = ["BC", "DE", "HL", "SP"]
ALU_OPS = ["ADD", "ADC", "SUB", "SBC", "AND", "XOR", "OR", "CP"]

def get_reg_access(r_str):
    if r_str == "A": return "AF", 8
    elif r_str == "B": return "BC", 8
    elif r_str == "C": return "BC", 0
    elif r_str == "D": return "DE", 8
    elif r_str == "E": return "DE", 0
    elif r_str == "H": return "HL", 8
    elif r_str == "L": return "HL", 0
    return None, 0

def alu_op_expected(op, a, b, flags_in_c=0):
    if op == "ADD": return (a + b) & 0xFF
    if op == "ADC": return (a + b + flags_in_c) & 0xFF
    if op == "SUB": return (a - b) & 0xFF
    if op == "SBC": return (a - b - flags_in_c) & 0xFF
    if op == "AND": return (a & b) & 0xFF
    if op == "XOR": return (a ^ b) & 0xFF
    if op == "OR": return (a | b) & 0xFF
    if op == "CP": return a
    return a

def get_test_header():
    return """import cocotb
from cocotb.clock import Clock
from test_utils import CPUMemory, reset_cpu, do_cycles

"""
