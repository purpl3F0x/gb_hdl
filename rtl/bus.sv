`timescale 1ns / 1ps

import boy_pkg::*;

module bus (

    input logic clk,
    input logic rst,

    bus_if.master cart_bus,  // Output to Cartridge

    bus_if.master ppu_bus,  // Output to PPU
    bus_if.master apu_bus,  // Output to APU
    bus_if.master ram_bus,  // Output to RAM
    bus_if.master oam_bus,  // Output to OAM
    bus_if.master io_bus,   // Output to I/O Devices
    bus_if.master hram_bus, // Output to High RAM

    bus_if.slave cpu_bus,  // Input from CPU


    // DMA
    input logic dma_active,
    input logic [7:0] dma_src_high,
    input logic [7:0] dma_dout,
    output logic [7:0] dma_din,
    output logic dma_we,
    output logic dma_re

);

  reg bootrom_mapped;
  reg [7:0] bootrom[256];  // 256 bytes of Boot ROM

  initial begin
    $readmemh("roms/dmg_boot.hex", bootrom);
  end

  always @(posedge clk) begin
    if (rst) begin
      bootrom_mapped <= 1'b1;  // Boot ROM is mapped at reset
    end else begin
      // Unmap Boot ROM when CPU writes to 0xFF50
      if (cpu_bus.we && (cpu_bus.addr == 16'hFF50)) begin
        bootrom_mapped <= 1'b0;
      end
    end
  end

  // TODO: Verilator gets confused on this statement it needs to be split into two
  always_comb begin
    // Default values for all buses
    cpu_bus.din   = 8'h00;

    ppu_bus.addr = 16'h0000;
    ppu_bus.dout = 8'h00;
    ppu_bus.we   = 1'b0;
    ppu_bus.re   = 1'b0;

    apu_bus.addr = 16'h0000;
    apu_bus.dout = 8'h00;
    apu_bus.we   = 1'b0;
    apu_bus.re   = 1'b0;

    ram_bus.addr = 13'h0000;
    ram_bus.dout = 8'h00;
    ram_bus.we   = 1'b0;
    ram_bus.re   = 1'b0;

    oam_bus.addr = 16'h0000;
    oam_bus.dout = 8'h00;
    oam_bus.we   = 1'b0;
    oam_bus.re   = 1'b0;

    io_bus.addr  = 16'h0000;
    io_bus.dout  = 8'h00;
    io_bus.we    = 1'b0;
    io_bus.re    = 1'b0;

    cart_bus.addr = 16'h0000;
    cart_bus.dout = 8'h00;
    cart_bus.we   = 1'b0;
    cart_bus.re   = 1'b0;

    hram_bus.addr = 7'h00;
    hram_bus.dout = 8'h00;
    hram_bus.we   = 1'b0;
    hram_bus.re   = 1'b0;


    // Address decoding logic

    unique case (cpu_bus.addr) inside

      // 16KiB + 16KiB Cartridge ROM (ROM0: 0000h – 3FFFh and ROMX: 4000h – 7FFFh) + Boot ROM (0000h - 00FFh)
      16'b0???_????_????_????: begin

        // if bootrom_is active and address is in bootrom range, access bootrom
        if (bootrom_mapped && (cpu_bus.addr[15:8] == 8'h00)) begin
          // Boot ROM is mapped
          if (cpu_bus.re) begin
            cpu_bus.din = bootrom[cpu_bus.addr[7:0]];
          end

        end else begin
          // Boot ROM is unmapped, access cartridge
          cart_bus.addr = cpu_bus.addr;
          cart_bus.dout = cpu_bus.dout;
          cart_bus.we   = cpu_bus.we;
          cart_bus.re   = cpu_bus.re;
          cpu_bus.din   = cart_bus.din;
        end
      end

      // 8KiB Video RAM (VRAM) (8000h – 9FFFh)
      16'b100?_????_????_????: begin
        ppu_bus.addr = cpu_bus.addr;
        ppu_bus.dout = cpu_bus.dout;
        ppu_bus.we   = cpu_bus.we;
        ppu_bus.re   = cpu_bus.re;
        cpu_bus.din  = ppu_bus.din;
      end

      // 8 KiB External RAM (A000h – BFFFh)
      16'b101?_????_????_????: begin
        cart_bus.addr = cpu_bus.addr;
        cart_bus.dout = cpu_bus.dout;
        cart_bus.we   = cpu_bus.we;
        cart_bus.re   = cpu_bus.re;
        cpu_bus.din   = cart_bus.din;
      end


      // 8KiB Work RAM (WRAM) (C000h – DFFFh)
      16'b110?_????_????_????: begin
        ram_bus.addr = cpu_bus.addr[12:0];
        ram_bus.dout = cpu_bus.dout;
        ram_bus.we   = cpu_bus.we;
        ram_bus.re   = cpu_bus.re;
        cpu_bus.din  = ram_bus.din;
      end

      // Echo RAM (E000h – FDFFh) - Mirror of C000h – DFFFh
      [16'hE000 : 16'hFDFF]: begin
        ram_bus.addr = cpu_bus.addr[12:0];
        ram_bus.dout = cpu_bus.dout;
        ram_bus.we   = cpu_bus.we;
        ram_bus.re   = cpu_bus.re;
        cpu_bus.din  = ram_bus.din;
      end


      // OAM (Object Attribute Memory) (FE00h – FE9Fh)
      [16'hFE00 : 16'hFE9F]: begin
        oam_bus.addr = cpu_bus.addr;
        oam_bus.dout = cpu_bus.dout;
        oam_bus.we   = cpu_bus.we;
        oam_bus.re   = cpu_bus.re;
        cpu_bus.din  = oam_bus.din;
      end

      // I/O Registers (FF00h – FF7Fh) // TODO: Maybe will be seperated
      16'b1111_1111_0???_????: begin
        if (cpu_bus.addr == 16'hFF44) begin
          cpu_bus.din = 8'h90;  // LY register always returns 0x90 for now
        end else begin
          io_bus.addr = cpu_bus.addr;
          io_bus.dout = cpu_bus.dout;
          io_bus.we   = cpu_bus.we;
          io_bus.re   = cpu_bus.re;
          cpu_bus.din = io_bus.din;
        end
      end

      // High RAM (HRAM) (FF80h – FFFEh)
      [16'hFF80 : 16'hFFFE]: begin
        hram_bus.addr = cpu_bus.addr[6:0];
        hram_bus.dout = cpu_bus.dout;
        hram_bus.we   = cpu_bus.we;
        hram_bus.re   = cpu_bus.re;
        cpu_bus.din   = hram_bus.din;
      end

      // IE Register
      16'hFFFF: begin
        // TODO
      end


      default: begin
        $error("Invalid address access: %h", cpu_bus.addr);
      end
    endcase

  end


endmodule
