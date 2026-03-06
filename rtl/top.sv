`timescale 1ns / 1ps

module top (
    input logic clk,
    input logic rst,

    bus_if.master cart_bus  // Output to Cartridge
);

  // Interfaces
  bus_if ppu_bus ();  // Output to PPU
  bus_if apu_bus ();  // Output to APU
  bus_if #(.ADDR_WIDTH(13)) ram_bus ();  // Output to RAM (8 KiB = 13 bits)
  bus_if oam_bus ();  // Output to OAM
  bus_if #(.ADDR_WIDTH(7)) hram_bus ();  // Output to High RAM    HRAM 127 byts = 7 bits

  bus_if #(.ADDR_WIDTH(2)) timer_bus ();  // Output to Timer (4 registers = 2 bits)

  bus_if cpu_bus ();  // Input from CPU

  // DMA signals
  wire dma_active;
  wire [7:0] dma_src_high;
  wire [7:0] dma_dout;
  wire [7:0] dma_din;
  wire dma_we;
  wire dma_re;


  // Instantiate Bus
  bus bus_inst (
      .clk(clk),
      .rst(rst),
      .ppu_bus(ppu_bus),
      .apu_bus(apu_bus),
      .ram_bus(ram_bus),
      .oam_bus(oam_bus),
      .cart_bus(cart_bus),
      .hram_bus(hram_bus),

      .timer_bus(timer_bus),

      .cpu_bus(cpu_bus),

      // DMA
      .dma_active(dma_active),
      .dma_src_high(dma_src_high),
      .dma_dout(dma_dout),
      .dma_din(dma_din),
      .dma_we(dma_we),
      .dma_re(dma_re)
  );

  // Instantiate CPU
  cpu CPU (
      .clk(clk),
      .rst(rst),
      .cpu_bus(cpu_bus.master)
  );

  // Instantiate RAM (8 KiB)
  ram #(
      .SIZE(8192)
  ) RAM (
      .clk(clk),
      .ram_bus(ram_bus.slave)
  );

  // HRAM
  ram #(
      .SIZE(128)
  ) HRAM (
      .clk(clk),
      .ram_bus(hram_bus.slave)
  );

  // DMA instance
  dma DMA (
      .clk(clk),
      .rst(rst),
      .we(dma_we),
      .re(dma_re),
      .din(dma_dout),
      .dout(dma_din),
      .dma_src_high(dma_src_high),
      .dma_active(dma_active)
  );

  // Instantiate Timer
  timer Timer (
      .clk_4(clk),  // TODO: Generate 4 MHz clock from main clock
      .clk(clk),
      .rst(rst),
      .stop(1'b0),  // TODO: Connect to CPU STOP mode
      .timer_bus(timer_bus.slave),  // Connect Timer to I/O bus
      .timer_irq(),  // TODO: Connect to CPU interrupt line
      .timer_irq_ack()  // TODO: Connect to CPU interrupt ack
  );


endmodule
