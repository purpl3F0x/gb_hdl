`timescale 1ns / 1ps

import boy_pkg::*;

module dma (
    input logic clk,
    input logic rst,

    // DMA has a signle register no need for a full bus interface
    input logic we,
    input logic re,
    input logic [7:0] din,

    output reg [7:0] dout,
    output reg [7:0] dma_src_high,
    output reg dma_active

);
  // Source:      $XX00-$XX9F   ;XX = $00 to $DF
  // Destination: $FE00-$FE9F
  // Writing to the DMA register starts a transfer of 160 bytes.

  reg start_dma;  // Delay DMA start by 1-cycle (so CPU can jump to HRAM)

  always @(posedge clk) begin
    if (rst) begin
      start_dma  <= 1'b0;
      dma_active <= 1'b0;
    end else begin

      if (dma_active) begin  // Active DMA transfer
        dout <= dout + 1;
        // DMA is complete
        if (dout == 8'h9F) begin
          dma_active <= 1'b0;
          start_dma <= 1'b0;
          dout <= 0;
        end

      end else if (start_dma) begin  // DMA Starting...
        dout <= 8'h00;
        dma_active <= 1;

      end else if (we) begin  // Write to DMA register
        dma_src_high <= din;
        start_dma <= 1'b1;
      end

    end
  end


endmodule

