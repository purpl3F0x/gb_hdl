`timescale 1ns / 1ps

import boy_pkg::*;


module ram #(
    parameter unsigned SIZE
) (
    input logic clk,
    bus_if.slave ram_bus
);

  reg [7:0] mem[SIZE];

  assign ram_bus.din = (ram_bus.re) ? mem[ram_bus.addr] : 8'b0;

  always @(posedge clk) begin
    if (ram_bus.we) begin
      mem[ram_bus.addr] <= ram_bus.dout;
    end
  end

endmodule
