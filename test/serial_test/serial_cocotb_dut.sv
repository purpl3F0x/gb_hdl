`timescale 1ns / 1ps

import boy_pkg::*;

module serial_cocotb_dut (
    input logic clk,
    input logic clk_4,
    input logic rst,
    input logic addr,
    input logic [7:0] wdata,
    input logic we,
    input logic re,
    output logic [7:0] rdata,
    output logic serial_irq,
    input logic serial_irq_ack,
    input logic si,
    output logic so,
    input logic sck_in,
    output logic sck_out
);

  bus_if #(.ADDR_WIDTH(1)) serial_bus ();

  assign serial_bus.addr = addr;
  assign serial_bus.dout = wdata;
  assign serial_bus.we = we;
  assign serial_bus.re = re;
  assign rdata = serial_bus.din;

  serial uut (
      .clk(clk),
      .clk_4(clk_4),
      .rst(rst),
      .serial_bus(serial_bus),
      .serial_irq(serial_irq),
      .serial_irq_ack(serial_irq_ack),
      .si(si),
      .so(so),
      .sck_in(sck_in),
      .sck_out(sck_out)
  );

endmodule
