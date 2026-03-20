`timescale 1ns / 1ps

import boy_pkg::*;


module ram #(
    parameter unsigned SIZE
) (
    input logic clk,
    bus_if.slave ram_bus
);

  reg [7:0] mem[SIZE];

  always @(negedge clk) begin
    if (ram_bus.re) begin
      ram_bus.din <= mem[ram_bus.addr];
    end else begin
      ram_bus.din <= 0;
    end
  end

  always @(posedge clk) begin
    if (ram_bus.we) begin
      mem[ram_bus.addr] <= ram_bus.dout;
    end
  end

endmodule
