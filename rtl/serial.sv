`timescale 1ns / 1ps


module serial (
    input logic clk,
    input logic clk_4,
    input logic rst,

    // Register Control
    bus_if.slave serial_bus,

    // IRQ
    output reg   serial_irq,
    input  logic serial_irq_ack,

    // External Interface
    input  logic si,
    output logic so,
    input  logic sck_in,
    output logic sck_out
);

  reg sc_en;  // Serial Transfer Enable. 1 = Transfer in progress/requested, 0 = when done.
  reg sc_clk_sel;  // 0 = External Clock (SCK), 1 = Internal Clock (8192 kHz)

  reg [7:0] sb;  // Serial Transfer Data (SB) (0xFF01)

  // Internal clock generation
  // 2^22 Hz / 512 = 8192 Hz
  reg [8:0] int_clk_div;
  reg int_sck_prev;
  always @(posedge clk_4) begin
    if (rst) begin
      int_clk_div  <= 0;
      int_sck_prev <= 1;
    end else if (sc_en && sc_clk_sel) begin
      int_clk_div  <= int_clk_div + 1;
      int_sck_prev <= ~int_clk_div[8];
    end else begin
      int_clk_div <= 0;
    end
  end

  wire int_sck = ~int_clk_div[8];
  wire int_clk_rising = (int_sck & ~int_sck_prev);
  wire int_clk_falling = (~int_sck & int_sck_prev);

  // Capture rising edge of clk for synchronous write logic
  reg  clk_d;
  always @(posedge clk_4) begin
    if (rst) begin
      clk_d <= 0;
    end
    clk_d <= clk;
  end

  wire rising_edge = (clk_d == 0) && clk;  // Detect rising edge of clk
  wire falling_edge = (clk_d == 1) && !clk;  // Detect falling edge of clk


  // Async input clock edge detection
  logic [2:0] sck_sync, si_sync;
  always @(posedge clk_4) begin
    sck_sync <= {sck_sync[1:0], sck_in};
    si_sync  <= {si_sync[1:0], si};
  end
  wire si_stable = si_sync[2];
  wire ext_clk_rising = (sck_sync[2:1] == 2'b01);
  wire ext_clk_falling = (sck_sync[2:1] == 2'b10);


  // Serial transfer logic
  reg [2:0] bit_count;
  wire shift_edge = sc_clk_sel ? int_clk_falling : ext_clk_falling;
  wire sample_edge = sc_clk_sel ? int_clk_rising : ext_clk_rising;

  assign sck_out = (sc_clk_sel && sc_en) ? int_sck : 1'b1;


  always @(posedge clk_4) begin
    if (rst) begin
      sc_en <= 1'b0;
      sc_clk_sel <= 1'b0;
      sb <= 8'h00;
      bit_count <= 3'b000;
      serial_irq <= 1'b0;

      //   sck_out <= 1'b1;
    end else begin

      // IRQ ACK
      if (serial_irq_ack == 1'b1) begin
        serial_irq <= 1'b0;
      end

      // Write logic
      if (rising_edge) begin
        if (serial_bus.we) begin
          unique case (serial_bus.addr)
            /* hFF02 */ 1'b0: begin
              sc_en <= serial_bus.dout[7];
              sc_clk_sel <= serial_bus.dout[0];
            end
            /* hFF01 */ 1'b1: sb <= serial_bus.dout;
            default;
          endcase
        end
      end

      // Read logic
      if (falling_edge) begin
        if (serial_bus.re) begin
          unique case (serial_bus.addr)
            /* hFF02 */ 1'b0: serial_bus.din <= {sc_en, 6'b111111, sc_clk_sel};
            /* hFF01 */ 1'b1: serial_bus.din <= sb;
            default;
          endcase
        end
      end

      if (sc_en) begin
        // sck_out <= sc_clk_sel ? int_sck : 1'b1;

        if (sample_edge) begin
          sb <= {sb[6:0], si_stable};
          bit_count <= bit_count + 1'b1;
          if (bit_count == 3'd7) begin
            sc_en <= 1'b0;  // End transfer after 8 bits
            serial_irq <= 1'b1;
          end

        end

        if (shift_edge) begin
          so <= sb[7];
        end

      end else begin
        // sck_out <= 1'b1;
        so <= 1'b1;
      end
    end
  end
endmodule
