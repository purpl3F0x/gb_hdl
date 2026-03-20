`timescale 1ns / 1ps

import boy_pkg::*;


module bootrom (
    input logic clk,
    bus_if.slave rom_bus
);

  reg [7:0] mem[256];

  initial begin
    $readmemh("roms/dmg_boot.hex", mem);
  end

  always @(negedge clk) begin
    if (rom_bus.re) begin
      rom_bus.din <= mem[rom_bus.addr];
    end else begin
      rom_bus.din <= 0;
    end
  end

endmodule
