`timescale 1ns / 1ps

module cpu_verilator_bridge (
    input logic clk,
    input logic rst,

    output logic [15:0] AF_out,
    output logic [15:0] BC_out,
    output logic [15:0] DE_out,
    output logic [15:0] HL_out,
    output logic [15:0] SP_out,
    output logic [15:0] PC_out,
    output logic [15:0] PC_current,
    output logic [2:0] m_cycle_out,
    output logic halted_out,
    output logic ime_out,

    input logic [7:0] data_in,
    output logic rd_en,
    output logic wr_en,
    output logic [15:0] addr_out,
    output logic [7:0] data_out
);

  bus_if cpu_bus ();

  assign cpu_bus.din = data_in;
  assign rd_en = cpu_bus.re;
  assign wr_en = cpu_bus.we;
  assign addr_out = cpu_bus.addr;
  assign data_out = cpu_bus.dout;

  cpu uut (
      .clk(clk),
      .rst(rst),
      .cpu_bus(cpu_bus.master)
  );

  always_comb begin
    AF_out = uut.reg_file.AF_next;
    BC_out = uut.reg_file.BC_next;
    DE_out = uut.reg_file.DE_next;
    HL_out = uut.reg_file.HL_next;
    SP_out = uut.reg_file.SP_next;
    PC_out = uut.reg_file.PC_reg;
    PC_current = uut.executing_pc;
    m_cycle_out = uut.control_unit.m_cycle_next;
    halted_out = uut.control_unit.comb_halt;
    ime_out = uut.control_unit.comb_ime;
  end

endmodule
