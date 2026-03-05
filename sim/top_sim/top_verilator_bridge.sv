`timescale 1ns / 1ps

module top_verilator_bridge (
    input logic clk,
    input logic rst,

    input logic [7:0] cart_din,
    output logic cart_re,
    output logic cart_we,
    output logic [15:0] cart_addr,
    output logic [7:0] cart_dout,

    output logic [15:0] AF_out,
    output logic [15:0] BC_out,
    output logic [15:0] DE_out,
    output logic [15:0] HL_out,
    output logic [15:0] SP_out,
    output logic [15:0] PC_out,
    output logic [15:0] executing_pc_out,
    output logic [2:0] m_cycle_out,
    output logic halted_out
);

  bus_if cart_bus ();

  top uut (
      .clk(clk),
      .rst(rst),
      .cart_bus(cart_bus.master)
  );

  always_comb begin
    cart_bus.din = cart_din;

    cart_re = cart_bus.re;
    cart_we = cart_bus.we;
    cart_addr = cart_bus.addr;
    cart_dout = cart_bus.dout;

    AF_out = uut.CPU.reg_file.AF_reg;
    BC_out = uut.CPU.reg_file.BC_reg;
    DE_out = uut.CPU.reg_file.DE_reg;
    HL_out = uut.CPU.reg_file.HL_reg;
    SP_out = uut.CPU.reg_file.SP_reg;
    PC_out = uut.CPU.reg_file.PC_reg;
`ifndef SYNTHESIS
    executing_pc_out = uut.CPU.executing_pc;
`else
    executing_pc_out = 16'h0000;
`endif
    m_cycle_out = uut.CPU.control_unit.m_cycle;
    halted_out = uut.CPU.control_unit.halt;
  end

endmodule
