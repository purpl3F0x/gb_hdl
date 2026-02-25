`timescale 1ns / 1ps

import alu_pkg::*;

module ALU (
    input logic en,
    input logic [7:0] A,
    input logic [7:0] B,
    input flags_t flags_in,
    input alu_op_t op,
    input logic [2:0] bit_idx,

    output logic [7:0] res,
    output flags_t flags_out
);

  function automatic [4:0] add4;
    input [3:0] a;
    input [3:0] b;
    input cin;
    begin
      add4 = a + b + cin;
    end
  endfunction


  always_comb begin

    res = 0;
    flags_out = flags_in;


    if (en) begin
      case (op)
        ADD, ADC, SUB, SBC, CP: begin
          logic [7:0] B_eff;
          logic h_c, c_c;

          B_eff = op[1] ? ~B : B;
          {h_c, res[3:0]} = add4(A[3:0], B_eff[3:0], (op[0] & flags_in.C) ^ op[1]);
          {c_c, res[7:4]} = add4(A[7:4], B_eff[7:4], h_c);

          flags_out.N = op[1];
          flags_out.H = h_c ^ op[1];
          flags_out.C = c_c ^ op[1];
          flags_out.Z = (res == 0);
          if (op == CP) res = 0;
        end

        AND: begin
          res = A & B;
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 1;
          flags_out.C = 0;
        end

        XOR: begin
          res = A ^ B;
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
          flags_out.C = 0;
        end

        OR: begin
          res = A | B;
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
          flags_out.C = 0;
        end

        // ******************* //
        // *  SHIFT,ROTATE   * //
        // ******************* //

        RLC: begin
          res = {A[6:0], A[7]};
          flags_out.C = A[7];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        RRC: begin
          res = {A[0], A[7:1]};
          flags_out.C = A[0];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        RL: begin
          res = {A[6:0], flags_in.C};
          flags_out.C = A[7];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        RR: begin
          res = {flags_in.C, A[7:1]};
          flags_out.C = A[0];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        SLA: begin
          res = {A[6:0], 1'b0};
          flags_out.C = A[7];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        SRA: begin
          res = {A[7], A[7:1]};
          flags_out.C = A[0];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        SWAP: begin
          res = {A[3:0], A[7:4]};
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
          flags_out.C = 0;
        end

        SRL: begin
          res = {1'b0, A[7:1]};
          flags_out.C = A[0];
          flags_out.Z = (res == 0);
          flags_out.N = 0;
          flags_out.H = 0;
        end

        // ******************* //
        // *     SPECIAL     * //
        // ******************* //

        SF: begin
          flags_out = B[7:4];
        end

        LF: begin
          res = {flags_out, 4'b0};
        end

        DAA: begin
          // This is as fast is it gets, maybe merging the chained muxes would help?
          // Another Idea is to pipeline the decision since only the ALU changes the flags

          logic adj_low, adj_high;
          logic [7:0] add_offset;
          adj_low  = flags_in.H || (A[3:0] > 4'h9);
          adj_high = flags_in.C || (A > 8'h99) || (adj_low && (A > 8'h93));

          if (flags_in.N == 0) begin
            case ({
              adj_high, adj_low
            })
              2'b00:   add_offset = 8'h00;  // No correction
              2'b01:   add_offset = 8'h06;  // Half-carry only
              2'b10:   add_offset = 8'h60;  // Carry only
              2'b11:   add_offset = 8'h66;  // Both
              default: add_offset = 8'h00;
            endcase
            flags_out.C = adj_high;

          end else begin  // flags_in.N == 1
            case ({
              flags_in.C, flags_in.H
            })
              2'b00:   add_offset = 8'h00;  // No correction
              2'b01:   add_offset = ~8'h06 + 1;  // Half-carry only
              2'b10:   add_offset = ~8'h60 + 1;  // Carry only
              2'b11:   add_offset = ~8'h66 + 1;  // Both
              default: add_offset = 8'h00;
            endcase

          end
          res = A + add_offset;

          flags_out.H = 0;
          flags_out.Z = (res == 0);
          flags_out.N = flags_in.N;
          // Res and CF assigned above

        end

        CPL: begin
          res = ~A;
          flags_out.H = 1;
          flags_out.N = 1;
        end

        CCF: begin
          flags_out.N = 0;
          flags_out.H = 0;
          flags_out.C = ~flags_in.C;
        end

        SCF: begin
          flags_out.N = 0;
          flags_out.H = 0;
          flags_out.C = 1;
        end


        // ******************* //
        // *     BIT OPS     * //
        // ******************* //

        BIT: begin
          flags_out.Z = ~A[bit_idx];
          flags_out.N = 0;
          flags_out.H = 1;
        end

        SET: begin
          res = A;
          res[bit_idx] = 1;
        end

        RES: begin
          res = A;
          res[bit_idx] = 0;
        end

        default: ;
      endcase

    end  // if (en)
  end
endmodule
