`timescale 1ns / 1ps

import boy_pkg::*;

module timer (
    input logic clk_4,

    input logic clk,

    input logic rst,
    input logic stop, // if cpu in STOP mode

    // Register Control
    bus_if.slave timer_bus,

    output reg   timer_irq,
    input  logic timer_irq_ack
    // output reg   falling_edge_detetor  // used  by APU
);

  reg [15:0] DIV;  // DIV[15:8]=(0xFF04): Incremented every M-cycle,
                   // so DIV[15:8] Incremented at a rate of 16384Hz.
                   // Writing any value resets it to 0. When STOP reset to 0 also.

  reg [7:0] TIMA;  // (0xFF05) Timer Counter. Incremented at the frequency specified by TAC.
                   // When it overflows, it is reset to the value in TMA and an interrupt is requested

  reg [7:0] TMA;  // (0xFF06) Timer Modulo. When TIMA overflows, it is reset to this value

  reg [3:0] TAC;  // (0xFF07) Timer Control. B2 = Enable, B1-B0 = Clock Select

  wire tac_en;
  wire [1:0] tac_freq;
  assign tac_en   = TAC[2];  // Timer Enable
  assign tac_freq = TAC[1:0];  // Clock Select
  logic selected_bit;  // The bit of DIV that is selected by TAC[1:0] for incrementing TIMA

  // Internal Registers
  reg bit_delay;  // Used for falling edge detection of the selected bit of DIV
  reg clk_d;  // Used to detecct rising edge of clk
  reg tma_overflow;
  reg [7:0] tma_next;  // Holds the next value of TIMA after overflow (TMA) for correct timing
  reg tma_update;

  // Read logic
  always_comb begin : READ_LOGIC
    timer_bus.din = 8'h00;

    if (timer_bus.re) begin
      unique case (timer_bus.addr)
        /* hFF04 */ 2'b00:   timer_bus.din = DIV[15:8];
        /* hFF05 */ 2'b01:   timer_bus.din = TIMA;
        /* hFF06 */ 2'b10:   timer_bus.din = TMA;
        /* hFF07 */ 2'b11:   timer_bus.din = {4'b1111, TAC};  // Unused IO reads 1s
        default;
      endcase
    end
  end

  always_comb begin : SELECT_BIT
    unique case (tac_freq)
      2'b00: selected_bit = DIV[9];  // 4096 Hz
      2'b01: selected_bit = DIV[3];  // 262144 Hz
      2'b10: selected_bit = DIV[5];  // 65536 Hz
      2'b11: selected_bit = DIV[7];  // 16384 Hz
    endcase
  end

  always @(posedge clk_4) begin
    if (rst) begin
      DIV          <= 16'h0000;
      TIMA         <= 8'h00;
      TMA          <= 8'h00;
      TAC          <= 4'h0;
      bit_delay    <= 1'b0;
      clk_d        <= 1'b1;
      timer_irq    <= 1'b0;
      tma_overflow <= 1'b0;
      tma_next     <= 8'h00;
    end else begin
      clk_d <= ~clk;

      if (stop) begin
        DIV <= 16'h00;
      end else begin
        DIV <= DIV + 16'h0001;

        // Falling edge detection on the selected bit of DIV
        bit_delay <= selected_bit & tac_en;  // Only consider the bit when timer is enabled

        if (bit_delay & ~selected_bit) begin  // Detect falling edge on selected DIV bit
          {tma_overflow, TIMA} <= TIMA + 8'h01;

          if (tma_overflow) begin
            TIMA <= TMA;  // Reset TIMA to TMA on overflow
            timer_irq <= 1'b1;  // Request interrupt on overflow
          end

        end
      end

      // Update TMA
      if (tma_update) begin
        TMA <= tma_next;
        tma_update <= 1'b0;
      end

      // Writes/ack only when clk and clk_4 rise together.
      if ((clk_d) & clk) begin
        if (timer_bus.we) begin
          unique case (timer_bus.addr)
            /* hFF04 */ 2'b00:   DIV <= 16'h0000;  // Writing to DIV resets it
            /* hFF05 */ 2'b01:   TIMA <= timer_bus.dout;
            /* hFF06 */ 2'b10: begin
              tma_next   <= timer_bus.dout;
              tma_update <= 1;
            end
            /* hFF07 */ 2'b11:   TAC <= timer_bus.dout[3:0];  // Only lower 4 bits are used
            default;
          endcase
        end

        if (timer_irq_ack) begin
          timer_irq <= 1'b0;
        end
      end

    end

  end

endmodule
