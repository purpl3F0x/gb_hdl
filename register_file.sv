
import cpu_pkg::*;
import alu_pkg::*;


module register_file (
    input clk,
    input rst,

    input read_r,
    input register_n_t read_reg_r,
    output logic [7:0] data_out_r,

    input read_rr,
    input register_nn_t read_reg_rr,
    output logic [15:0] data_out_rr,

    input flags_we,
    input flags_t flag_mask_n, // Active low mask for flags write enable
    input flags_t flags_in,

    input write_r,
    input register_n_t write_reg_r,
    input [7:0] data_in_r,

    input write_rr,
    input register_nn_t write_reg_rr,
    input [15:0] data_in_rr,

    output [7:0] A_out,
    output flags_t flags_out
);
  logic [15:0] AF_reg;
  logic [15:0] BC_reg;
  logic [15:0] DE_reg;
  logic [15:0] HL_reg;
  logic [15:0] SP_reg;
  logic [15:0] PC_reg;

  assign A_out = AF_reg[15:8];

  assign flags_out = AF_reg[7:4];

  always_comb begin
    // Read single 8-bit register
    if (read_r) begin
      case (read_reg_r)
        A: data_out_r = AF_reg[15:8];
        F: data_out_r = AF_reg[7:0];
        B: data_out_r = BC_reg[15:8];
        C: data_out_r = BC_reg[7:0];
        D: data_out_r = DE_reg[15:8];
        E: data_out_r = DE_reg[7:0];
        H: data_out_r = HL_reg[15:8];
        L: data_out_r = HL_reg[7:0];
        default: data_out_r = 8'h00;
      endcase
    end else begin
      data_out_r = 8'h00;
    end

    // Read 16-bit register pair
    if (read_rr) begin
      case (read_reg_rr)
        BC: data_out_rr = BC_reg;
        DE: data_out_rr = DE_reg;
        HL: data_out_rr = HL_reg;
        SP: data_out_rr = SP_reg;
        PC: data_out_rr = PC_reg;
        default: data_out_rr = 16'h0000;
      endcase
    end else begin
      data_out_rr = 16'h0000;
    end

  end



  always @(posedge clk) begin
    if (rst) begin
      AF_reg <= 16'h0000;
      BC_reg <= 16'h0000;
      DE_reg <= 16'h0000;
      HL_reg <= 16'h0000;
      SP_reg <= 16'h0000;
      PC_reg <= 16'h0000;

    end else begin

      if (write_r) begin
        case (write_reg_r)
          A: AF_reg[15:8] <= data_in_r;
          F: AF_reg[7:4] <= data_in_r[7:4];
          B: BC_reg[15:8] <= data_in_r;
          C: BC_reg[7:0] <= data_in_r;
          D: DE_reg[15:8] <= data_in_r;
          E: DE_reg[7:0] <= data_in_r;
          H: HL_reg[15:8] <= data_in_r;
          L: HL_reg[7:0] <= data_in_r;
          default: ;
        endcase
      end

      if (flags_we) begin
        AF_reg[7:4] <= (AF_reg[7:4] & flag_mask_n) | (flags_in & ~flag_mask_n);
      end

      if (write_rr) begin
        case (write_reg_rr)
          BC: BC_reg <= data_in_rr;
          DE: DE_reg <= data_in_rr;
          HL: HL_reg <= data_in_rr;
          SP: SP_reg <= data_in_rr;
          PC: PC_reg <= data_in_rr;
          default: ;
        endcase
      end
    end
  end

endmodule
