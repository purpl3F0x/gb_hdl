`timescale 1ns / 1ps

import alu_pkg::*;

module cpu (
    input logic clk,
    input logic rst,

    input logic [7:0] data_in,

    output wire rd_en,
    output wire wr_en,
    output wire [15:0] addr_out,
    output wire [7:0] data_out
);

  reg rst_sync;  // synchronized reset for combinational logic (control unit)

  reg [7:0] opcode;
  reg [7:0] cb_opcode;
  data_out_ctrl_t data_out_ctrl;

  // Register File
  logic [7:0] rf_data_out_r, rf_data_in_r;
  logic [15:0] rf_data_out_rr, rf_data_in_rr;
  logic [7:0] rf_A, rf_H, rf_L;
  flags_t rf_flags_out;
  logic rf_read_r, rf_read_rr, rf_write_r, rf_write_rr, rf_flags_we;
  register_n_t rf_read_reg_r, rf_write_reg_r;
  register_nn_t rf_read_reg_rr, rf_write_reg_rr;
  flags_t rf_flag_mask_n, rf_flags_in;
  // Internal 16-bit copy control
  copy_wz_to_rr_op_t rf_copy_wz_to_rr_op;
  // Bus opcode coming from `control`
  bus_opcode_t bus_op;



  register_file reg_file (
      .clk(clk),
      .rst(rst),
      .read_r(rf_read_r),
      .read_reg_r(rf_read_reg_r),
      .data_out_r(rf_data_out_r),
      .read_rr(rf_read_rr),
      .read_reg_rr(rf_read_reg_rr),
      .data_out_rr(rf_data_out_rr),
      .flags_we(rf_flags_we),
      .flag_mask_n(rf_flag_mask_n),
      .flags_in(rf_flags_in),
      .write_r(rf_write_r),
      .write_reg_r(rf_write_reg_r),
      .data_in_r(rf_data_in_r),
      .write_rr(rf_write_rr),
      .write_reg_rr(rf_write_reg_rr),
      .data_in_rr(rf_data_in_rr),
      .copy_wz_to_rr_op(rf_copy_wz_to_rr_op),
      .A_out(rf_A),
      .H_out(rf_H),
      .L_out(rf_L),
      .flags_out(rf_flags_out)
  );

  wire idu_op, idu_en;
  wire [15:0] idu_dout;

  idu idu_unit (
      .en(idu_en),
      .op(idu_op),
      .data_in(rf_data_out_rr),
      .data_out(idu_dout)
  );

  assign rf_data_in_rr = idu_dout;


  wire alu_en;
  alu_op_t alu_op;
  wire [2:0] alu_bit_idx;
  alu_src_a_select_t alu_src_a_select;
  alu_src_b_select_t alu_src_b_select;
  logic [7:0] alu_A, alu_B, alu_res;


  control control_unit (
      .clk(clk),
      .rst(rst_sync),
      .next_opcode(opcode),
      .cb_opcode(cb_opcode),
      .bus_opcode_out(bus_op),

      .idu_op(idu_op),
      .idu_en(idu_en),

      .rf_read_reg_r(rf_read_reg_r),
      .rf_read_r(rf_read_r),
      .rf_write_reg_r(rf_write_reg_r),
      .rf_write_r(rf_write_r),

      .rf_read_reg_rr(rf_read_reg_rr),
      .rf_read_rr(rf_read_rr),
      .rf_write_reg_rr(rf_write_reg_rr),
      .rf_write_rr(rf_write_rr),
      .rf_copy_wz_to_rr_op(rf_copy_wz_to_rr_op),
      .rf_flags_we(rf_flags_we),
      .rf_flag_mask_n(rf_flag_mask_n),

      .alu_en(alu_en),
      .alu_op(alu_op),
      .alu_bit_idx(alu_bit_idx),
      .alu_src_a_select(alu_src_a_select),
      .alu_src_b_select(alu_src_b_select),

      .data_out_ctrl(data_out_ctrl)
  );


  always_comb begin
    alu_A = rf_A;
    alu_B = 8'h00;

    case (alu_src_a_select)
      ALU_SRC_A_A:   alu_A = rf_A;
      ALU_SRC_A_REG: alu_A = rf_data_out_r;
      ALU_SRC_A_L:   alu_A = rf_L;
      ALU_SRC_A_H:   alu_A = rf_H;
      default;
    endcase

    case (alu_src_b_select)
      ALU_SRC_B_REG:  alu_B = rf_data_out_r;
      ALU_SRC_B_ZERO: alu_B = 8'h00;
      ALU_SRC_B_ONE:  alu_B = 8'h01;
      default;
    endcase

  end


  ALU alu_unit (
      .en(alu_en),
      .A(alu_A),
      .B(alu_B),
      .flags_in(rf_flags_out),
      .op(alu_op),
      .bit_idx(alu_bit_idx),
      .flags_out(rf_flags_in),
      .res(alu_res)
  );
  // Might not be always correct
  assign rf_data_in_r = alu_en ? alu_res : data_in;

  // BUS operations
  assign rd_en = (bus_op == IF) || (bus_op == READ) || (bus_op == IF_CB);
  assign wr_en = (bus_op == WRITE);
  assign addr_out = (bus_op == IF || bus_op == READ || bus_op == WRITE || bus_op == IF_CB) ? rf_data_out_rr : 16'h0;
  assign data_out = (bus_op == WRITE) ?
                    ((data_out_ctrl == DOUT_FROM_ALU_RES) ? alu_res : rf_data_out_r)
                    : 8'h00; // TODO: This can probably be merged to checking if ALU is enabled

  // For metrics
  reg [47:0] counter;  // 8.5 years should be enough for tracing :)

  always @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      opcode <= 8'h00;
      cb_opcode <= 8'h00;
      rst_sync <= 1;
    end else begin
      rst_sync <= 0;
      counter  <= counter + 1;

      case (bus_op)
        IF: begin
          opcode <= data_in[7:0];
        end

        WRITE: begin
        end

        READ: begin
        end

        IF_CB: begin
          cb_opcode <= data_in[7:0];
        end

        default;
      endcase
    end
  end

endmodule
