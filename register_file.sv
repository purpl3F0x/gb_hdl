
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
    input flags_t flag_mask_n,  // Active low mask for flags write enable
    input flags_t flags_in,

    input write_r,
    input register_n_t write_reg_r,
    input [7:0] data_in_r,

    input write_rr,
    input register_nn_t write_reg_rr,
    input [15:0] data_in_rr,

    input copy_wz_to_rr_op_t copy_wz_to_rr_op,  // Will copy WZ to the specified register if active

    output [7:0] A_out,
    output [7:0] H_out,
    output [7:0] L_out,
    output flags_t flags_out
);
  logic [15:0] AF_reg;
  logic [15:0] BC_reg;
  logic [15:0] DE_reg;
  logic [15:0] HL_reg;
  logic [15:0] SP_reg;
  logic [15:0] PC_reg;

  logic [15:0] WZ_reg;  // temp register


  assign A_out = AF_reg[15:8];
  assign H_out = HL_reg[15:8];
  assign L_out = HL_reg[7:0];

  assign flags_out = AF_reg[7:4];

  always_comb begin
    // Read single 8-bit register
    if (read_r) begin
      case (read_reg_r)
        A: data_out_r = AF_reg[15:8];
        Z: data_out_r = WZ_reg[7:0];
        B: data_out_r = BC_reg[15:8];
        C: data_out_r = BC_reg[7:0];
        D: data_out_r = DE_reg[15:8];
        E: data_out_r = DE_reg[7:0];
        H: data_out_r = HL_reg[15:8];
        L: data_out_r = HL_reg[7:0];
        SPH: data_out_r = SP_reg[15:8];
        SPL: data_out_r = SP_reg[7:0];
        W: data_out_r = SP_reg[15:8];
        F: data_out_r = AF_reg[7:0];
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
        WZ: data_out_rr = WZ_reg;
        LDH_Z: data_out_rr = {8'hFF, WZ_reg[7:0]};
        LDH_C: data_out_rr = {8'hFF, BC_reg[7:0]};
        default: data_out_rr = 16'h0000;
      endcase
    end else begin
      data_out_rr = 16'h0000;
    end

  end

  //  16-bit register copy (with some heave sanity checks)
  always @(posedge clk) begin
    if ((rst == 0) && (write_reg_rr == PC || write_reg_r == 0)) begin
      case (copy_wz_to_rr_op)
        COPY_WZ_TO_BC: BC_reg <= WZ_reg;
        COPY_WZ_TO_DE: DE_reg <= WZ_reg;
        COPY_WZ_TO_HL: HL_reg <= WZ_reg;
        COPY_WZ_TO_SP: SP_reg <= WZ_reg;
        COPY_WZ_TO_AF: AF_reg[15:4] <= WZ_reg[15:4];
        default: ;
      endcase
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
      WZ_reg <= 16'h0000;

    end else begin
      if (write_r) begin
        case (write_reg_r)
          A: AF_reg[15:8] <= data_in_r;
          Z: WZ_reg[7:0] <= data_in_r;
          B: BC_reg[15:8] <= data_in_r;
          C: BC_reg[7:0] <= data_in_r;
          D: DE_reg[15:8] <= data_in_r;
          E: DE_reg[7:0] <= data_in_r;
          H: HL_reg[15:8] <= data_in_r;
          L: HL_reg[7:0] <= data_in_r;
          SPH: SP_reg[15:8] <= data_in_r;
          SPL: SP_reg[7:0] <= data_in_r;
          W: WZ_reg[15:8] <= data_in_r;
          F: AF_reg[7:0] <= data_in_r;
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
          WZ: WZ_reg <= data_in_rr;
          default: ;
        endcase
      end
    end
  end

endmodule
