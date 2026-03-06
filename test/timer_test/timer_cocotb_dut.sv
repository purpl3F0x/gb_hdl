`timescale 1ns / 1ps

import boy_pkg::*;

module timer_cocotb_dut (
  input logic clk_4,
    input logic clk,
    input logic rst,
    input logic stop,
    input logic [15:0] addr,
    input logic [7:0] wdata,
    input logic we,
    input logic re,
    output logic [7:0] rdata,
    output logic timer_irq,
    input logic timer_irq_ack
);

  bus_if timer_bus ();

  assign timer_bus.addr = addr;
  assign timer_bus.dout = wdata;
  assign timer_bus.we = we;
  assign timer_bus.re = re;
  assign rdata = timer_bus.din;

  timer uut (
      .clk_4(clk_4),
      .clk(clk),
      .rst(rst),
      .stop(stop),
      .timer_bus(timer_bus),
      .timer_irq(timer_irq),
      .timer_irq_ack(timer_irq_ack)
  );

endmodule
