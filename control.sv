import alu_pkg::*;
import cpu_pkg::*;


module control (
    input clk,
    input rst,

    input [7:0] next_opcode,
    input [7:0] cb_opcode,

    input flags_t rf_flags,

    // Out BUS control
    output bus_opcode_t bus_opcode_out,

    // IDU control signals
    output idu_op_t idu_op,
    output reg idu_en,

    // Register File control signals
    // For single 8-bit register reads/writes
    output reg rf_read_r,
    output register_n_t rf_read_reg_r,
    output reg rf_write_r,
    output register_n_t rf_write_reg_r,
    // For 16-bit register pair reads/writes
    output register_nn_t rf_read_reg_rr,
    output reg rf_read_rr,
    output register_nn_t rf_write_reg_rr,
    output reg rf_write_rr,
    output copy_wz_to_rr_op_t rf_copy_wz_to_rr_op,
    output reg rf_copy_wz_to_rr_en,
    output reg rf_pc_rst,
    // For flags register writes
    output reg rf_flags_we,
    output flags_t rf_flag_mask_n,


    // ALU control signals
    output reg alu_en,
    output alu_op_t alu_op,
    output reg [2:0] alu_bit_idx,
    output alu_src_a_select_t alu_src_a_select,
    output alu_src_b_select_t alu_src_b_select,

    // Din register control
    output data_out_ctrl_t data_out_ctrl
);

  reg [7:0] decoded_opcode;

  reg [2:0] m_cycle, m_cycle_next;

  logic [7:0] comb_decoded_opcode;
  bus_opcode_t comb_bus_opcode_out;
  idu_op_t comb_idu_op;
  reg comb_idu_en;
  reg comb_rf_read_r;
  register_n_t comb_rf_read_reg_r;
  reg comb_rf_write_r;
  register_n_t comb_rf_write_reg_r;
  reg comb_rf_read_rr;
  register_nn_t comb_rf_read_reg_rr;
  reg comb_rf_write_rr;
  register_nn_t comb_rf_write_reg_rr;
  copy_wz_to_rr_op_t comb_rf_copy_wz_to_rr_op;
  reg comb_rf_copy_wz_to_rr_en;
  reg comb_rf_pc_rst;
  reg comb_rf_flags_we;
  flags_t comb_rf_flag_mask_n;

  reg comb_alu_en;
  alu_op_t comb_alu_op;
  reg [2:0] comb_alu_bit_idx;
  alu_src_a_select_t comb_alu_src_a_select;
  alu_src_b_select_t comb_alu_src_b_select;

  data_out_ctrl_t comb_data_out_ctrl;


  always_comb begin
    comb_decoded_opcode = 8'h00;
    comb_bus_opcode_out = IDLE;
    comb_idu_op = IDU_INC;
    comb_idu_en = 0;
    comb_rf_read_r = 0;
    comb_rf_read_reg_r = A;
    comb_rf_write_r = 0;
    comb_rf_write_reg_r = A;
    comb_rf_read_rr = 0;
    comb_rf_read_reg_rr = BC;
    comb_rf_write_rr = 0;
    comb_rf_write_reg_rr = BC;
    comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_BC;
    comb_rf_copy_wz_to_rr_en = 0;
    comb_rf_pc_rst = 0;
    comb_rf_flags_we = 0;
    comb_rf_flag_mask_n = 4'b0000;

    comb_alu_en = 0;
    comb_alu_op = ADD;
    comb_alu_bit_idx = 3'b000;
    comb_alu_src_a_select = ALU_SRC_A_REG;
    comb_alu_src_b_select = ALU_SRC_B_ONE;

    comb_data_out_ctrl = DOUT_FROM_ALU_RES;

    if (rst) begin
      m_cycle_next = 0;
    end

    if (!rst) begin
      comb_decoded_opcode = (m_cycle == 0) ? next_opcode : decoded_opcode;
      comb_bus_opcode_out = IF;
      comb_idu_op = IDU_INC;
      comb_idu_en = 1;

      comb_rf_read_rr = 0;
      comb_rf_read_reg_r = A;
      comb_rf_write_r = 0;
      comb_rf_write_reg_r = A;

      comb_rf_read_rr = 1;
      comb_rf_read_reg_rr = PC;
      comb_rf_write_rr = 1;
      comb_rf_write_reg_rr = PC;

      comb_rf_flags_we = 0;
      comb_rf_flag_mask_n = 4'b0000;

      // NOP
      if (comb_decoded_opcode == 8'h00) begin
      end //.

      // 16-bit LD from imm
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[3:0] == 4'b0001) begin
        if (m_cycle == 0) begin
          // M2
          // PC = PC + 1
          // Z = Read LSB
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3
          // PC = PC + 1
          // W = Read MSB
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else begin
          // M4/M1
          m_cycle_next = 0;
          comb_rf_copy_wz_to_rr_op = copy_wz_to_rr_op_t'({1'b0, comb_decoded_opcode[5:4]});
          comb_rf_copy_wz_to_rr_en = 1;
        end
      end //.

      // LD [BC/DE], A
      else if (comb_decoded_opcode[7:5] == 3'b000 && comb_decoded_opcode[3:0] == 4'b0010) begin
        if (m_cycle == 0) begin
          // M2: @[BC/DE] = A
          m_cycle_next = 1;

          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = register_nn_t'({2'b00, comb_decoded_opcode[4]});
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = A;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;

          comb_idu_en = 0;
          comb_rf_write_rr = 0;
        end else begin
          // M3: IF
          m_cycle_next = 0;
        end
      end //.

      // LD A, [BC/DE]
      else if (comb_decoded_opcode[7:5] == 3'b000 && comb_decoded_opcode[3:0] == 4'b1010) begin
        if (m_cycle == 0) begin
          // M2: @[BC/DE] = A
          m_cycle_next = 1;

          comb_bus_opcode_out = READ;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = register_nn_t'({2'b00, comb_decoded_opcode[4]});
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;

          comb_idu_en = 0;
          comb_rf_write_rr = 0;
        end else begin
          // M3: IF and A = Z
          m_cycle_next = 0;

          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_alu_op = PASS;
          comb_alu_en = 1;
          comb_rf_flags_we = 0;
        end
      end //.

      // LD [HL+/-]
      else if (comb_decoded_opcode[7:5] == 3'b001 && comb_decoded_opcode[3:0] == 4'b0010) begin
        if (m_cycle == 0) begin
          // M2: [HL] = A
          m_cycle_next = 1;

          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = HL;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = A;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;

          // Also +/- the HL
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = HL;
          comb_idu_en = 1;
          comb_idu_op = idu_op_t'(comb_decoded_opcode[4] == 1'b0 ? IDU_INC : IDU_DEC);
        end else begin
          // M3: IF
          m_cycle_next = 0;
        end
      end //.

       // LD A, [HL+/-]
      else if (comb_decoded_opcode[7:5] == 3'b001 && comb_decoded_opcode[3:0] == 4'b1010) begin
        if (m_cycle == 0) begin
          // M2: A = [HL]
          m_cycle_next = 1;

          comb_bus_opcode_out = READ;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = HL;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // Also +/- the HL
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = HL;
          comb_idu_en = 1;
          comb_idu_op = idu_op_t'(comb_decoded_opcode[4] == 1'b0 ? IDU_INC : IDU_DEC);
        end else begin
          // M3: IF and A = Z
          m_cycle_next = 0;

          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_alu_op = PASS;
          comb_alu_en = 1;
          comb_rf_flags_we = 0;
        end
      end //.


      // 8-bit imm2reg, imm2mem LD
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[2:0] == 3'b110) begin

        if (m_cycle == 0) begin
          // M1 :read n, PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else begin
          if (comb_decoded_opcode[5:3] == 3'b110) begin
            if (m_cycle == 1) begin
              m_cycle_next = 2;
              comb_rf_read_r = 1;
              comb_rf_read_reg_r = Z;
              comb_alu_src_a_select = ALU_SRC_A_REG;
              comb_bus_opcode_out = WRITE;
              comb_rf_read_rr = 1;
              comb_rf_read_reg_rr = HL;
              comb_alu_op = PASS;
              comb_alu_en = 1;
              comb_rf_flags_we = 0;
              comb_idu_en = 0;
              comb_rf_write_rr = 0;
            end else begin
              // M4/M1: PC = PC + 1
              m_cycle_next = 0;
            end

          end else begin
            // M3
            m_cycle_next = 0;
            comb_rf_write_r = 1;
            comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
            comb_rf_read_r = 1;
            comb_rf_read_reg_r = Z;
            comb_alu_src_a_select = ALU_SRC_A_REG;
            comb_alu_op = PASS;
            comb_alu_en = 1;
            comb_rf_flags_we = 0;
          end
        end

      end  //.

      // LD [a16], SP
      else if (comb_decoded_opcode == 8'h08) begin
        if (m_cycle == 0) begin
          // M2: Z = LSB
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: W = MSB
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else if (m_cycle == 2) begin
          // M4
          // @[WZ] = SPL
          m_cycle_next = 3;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = SPL;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // WZ = WZ + 1
          comb_idu_en = 1;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = WZ;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = WZ;
        end else if (m_cycle == 3) begin
          // M5
          // @[WZ+1] = SPH
          m_cycle_next = 4;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = SPH;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = WZ;
          comb_idu_en = 0;
          comb_rf_write_rr = 0;
        end else begin
          // M6/M1: IF
          m_cycle_next = 0;
        end

      end //.

      // ADD HL, R16
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[3:0] == 4'b1001) begin
        if (m_cycle == 0) begin
          // M2: L = L + R16_LOW
          m_cycle_next = 1;

          // Don't increment PC
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;

          // L = L + R16_LOW
          comb_alu_en = 1;
          comb_alu_op = ADD;
          comb_alu_src_a_select = ALU_SRC_A_L;
          comb_alu_src_b_select = ALU_SRC_B_REG;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = L;
          comb_rf_flags_we = 1;
          comb_rf_flag_mask_n.Z = 1;  // Z flag remains unchanged
          comb_rf_read_r = 1;
          case (comb_decoded_opcode[5:4])
            2'b00:   comb_rf_read_reg_r = C;
            2'b01:   comb_rf_read_reg_r = E;
            2'b10:   comb_rf_read_reg_r = L;
            2'b11:   comb_rf_read_reg_r = SPL;
            default: ;
          endcase
        end else begin
          // M3/M1: IF and H = H + R16_HIGH + Carry
          m_cycle_next = 0;

          comb_alu_en = 1;
          comb_alu_op = ADC;
          comb_alu_src_a_select = ALU_SRC_A_H;
          comb_alu_src_b_select = ALU_SRC_B_REG;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = H;
          comb_rf_flags_we = 1;
          comb_rf_flag_mask_n.Z = 1;  // Z flag remains unchanged
          comb_rf_read_r = 1;
          case (comb_decoded_opcode[5:4])
            2'b00:   comb_rf_read_reg_r = B;
            2'b01:   comb_rf_read_reg_r = D;
            2'b10:   comb_rf_read_reg_r = H;
            2'b11:   comb_rf_read_reg_r = SPH;
            default: ;
          endcase
        end
      end //.

      // 16-bit INC/DEC
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[2:0] == 3'b011) begin

        if (m_cycle == 0) begin
          // M2: INC/DEC RR
          m_cycle_next = 1;
          comb_bus_opcode_out = IDLE;
          comb_idu_en = 1;
          comb_idu_op = idu_op_t'(comb_decoded_opcode[3] == 1'b0 ? IDU_INC : IDU_DEC);
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = register_nn_t'(comb_decoded_opcode[5:4]);
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = register_nn_t'(comb_decoded_opcode[5:4]);
        end else begin
          // M3/M1: IF
          comb_bus_opcode_out = IF;
          m_cycle_next = 0;
        end

      end //.
      // 8-bit INC/DEC
      else if ((comb_decoded_opcode[7:6] == 2'b00) && (comb_decoded_opcode[2:1] == 2'b10)) begin

        if (comb_decoded_opcode[5:3] == 3'b110) begin  // INC/DEC (HL)
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;

          if (m_cycle == 0) begin
            // M1: READ
            m_cycle_next = 1;
            comb_bus_opcode_out = READ;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_rf_write_r = 1;
            comb_rf_write_reg_r = Z;

          end else if (m_cycle == 1) begin
            // M2: ALU + WRITE_BACK
            m_cycle_next = 2;

            comb_bus_opcode_out = WRITE;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;

            comb_rf_read_r = 1;
            comb_rf_read_reg_r = Z;

            comb_alu_en = 1;
            comb_alu_src_a_select = ALU_SRC_A_REG;
            comb_alu_src_b_select = ALU_SRC_B_ONE;
            comb_alu_op = alu_op_t'(comb_decoded_opcode[0] == 3'b000 ? ADD : SUB);

          end else if (m_cycle == 2) begin
            // M4/M1: IF
            m_cycle_next = 0;
          end

        end else begin
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_alu_src_b_select = ALU_SRC_B_ONE;
          comb_alu_op = alu_op_t'(comb_decoded_opcode[0] == 3'b000 ? ADD : SUB);
          comb_alu_en = 1;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
          comb_rf_flags_we = 1;
          comb_rf_flag_mask_n.C = 1;
        end
      end //.

      // 8-bit reg2reg mem2reg, reg2mem LD
      else if (comb_decoded_opcode[7:6] == 2'b01) begin

        if (comb_decoded_opcode[2:0] == 3'b110) begin  // LD R, [HL]

          if (m_cycle == 0) begin  // M2 read to tmp
            m_cycle_next = 1;
            // Skip PC+1
            comb_idu_en = 0;
            comb_rf_write_rr = 0;

            comb_bus_opcode_out = READ;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_rf_write_reg_r = Z;
            comb_rf_write_r = 1;

          end else begin  // M3/M1 IF
            m_cycle_next = 0;
            // R = Z
            comb_rf_write_r = 1;
            comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
            comb_rf_read_r = 1;
            comb_rf_read_reg_r = Z;
            comb_alu_src_a_select = ALU_SRC_A_REG;
            comb_alu_op = PASS;
            comb_alu_en = 1;
            comb_rf_flags_we = 0;
          end
        end else if (comb_decoded_opcode[5:3] == 3'b110) begin  // LD [HL], R
          if (m_cycle == 0) begin  // M2: Write to [HL]
            m_cycle_next = 1;
            comb_data_out_ctrl = DOUT_FROM_REG_FILE;
            comb_bus_opcode_out = WRITE;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_rf_read_r = 1;
            comb_rf_read_reg_r = register_n_t'(comb_decoded_opcode[2:0]);
            // Skip PC+1
            comb_idu_en = 0;
            comb_rf_write_rr = 0;

          end else begin  // M3 / M1 nothing happens just IF
            m_cycle_next = 0;
            // PC = PC + 1
          end

        end else begin  // LD R, R'
          // R = R'
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = register_n_t'(comb_decoded_opcode[2:0]);
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_alu_op = PASS;
          comb_alu_en = 1;
          comb_rf_flags_we = 0;
        end

      end //.
      // 8-bit ALU OP reg2reg, mem2reg
      else if (comb_decoded_opcode[7:6] == 2'b10) begin
        comb_alu_src_a_select = ALU_SRC_A_A;

        // From HL
        if (comb_decoded_opcode[2:0] == 3'b110) begin
          if (m_cycle == 0) begin
            // M2: Read [HL] to Z

            m_cycle_next = 1;
            // Don't Increment PC
            comb_idu_en = 0;
            comb_rf_read_rr = 0;
            comb_rf_write_rr = 0;

            comb_bus_opcode_out = READ;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_rf_write_reg_r = Z;
            comb_rf_write_r = 1;

          end else begin  // M3: ALU OP + IF
            m_cycle_next = 0;
            // Do the ALU operation
            comb_alu_src_b_select = ALU_SRC_B_REG;
            comb_alu_en = 1;
            comb_alu_op = alu_op_t'({2'b00, comb_decoded_opcode[5:3]});
            // Read Z
            comb_rf_read_r = 1;
            comb_rf_read_reg_r = Z;
            // Write Result to A and update flags
            comb_rf_write_r = (comb_decoded_opcode[5:3] != 3'b111);  // We don't write on CP
            comb_rf_write_reg_r = A;
            comb_rf_flags_we = 1;
          end
        end // if from [HL]
        else begin
          comb_rf_write_r = (comb_decoded_opcode[5:3] != 3'b111);  // We don't write on CP
          comb_rf_write_reg_r = A;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = register_n_t'(comb_decoded_opcode[2:0]);
          comb_rf_flags_we = 1;

          comb_alu_src_b_select = ALU_SRC_B_REG;
          comb_alu_op = alu_op_t'({2'b00, comb_decoded_opcode[5:3]});
          comb_alu_en = 1;
        end

      end //.
      // 8-bit ALU OP imm2reg
      else if (comb_decoded_opcode[7:6] == 2'b11 && comb_decoded_opcode[2:0] == 3'b110) begin
        if (m_cycle == 0) begin
          // M2 Mem fetch from PC+1
          m_cycle_next = 1;
          // Increment PC, but fetch as data to TMP
          comb_bus_opcode_out = READ;
          comb_rf_write_reg_r = Z;
          comb_rf_write_r = 1;

        end else begin
          //  M3/M1
          m_cycle_next = 0;
          comb_rf_write_r = (comb_decoded_opcode[5:3] != 3'b111);  // We don't write on CP
          comb_rf_write_reg_r = A;
          comb_alu_src_a_select = ALU_SRC_A_A;
          comb_alu_src_b_select = ALU_SRC_B_REG;
          comb_rf_read_reg_r = Z;
          comb_rf_read_r = 1;
          comb_alu_op = alu_op_t'({2'b00, comb_decoded_opcode[5:3]});
          comb_alu_en = 1;
          comb_rf_flags_we = 1;
        end
      end //.

      // POP R16
      else if (comb_decoded_opcode[7:6] == 2'b11 && comb_decoded_opcode[3:0] == 4'b0001) begin

        // M2: Z = LSB, SP = SP + 1
        if (m_cycle == 0) begin
          // M2: Z = LSB, SP = SP + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          // SP = SP + 1
          comb_idu_en = 1;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 1) begin
          // M3: W = MSB, SP = SP + 1
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
          // SP = SP + 1
          comb_idu_en = 1;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else begin
          // M4/M1: rr = WZ, IF
          m_cycle_next = 0;
          comb_rf_copy_wz_to_rr_en = 1;
          case (comb_decoded_opcode[5:4])
            2'b00:   comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_BC;
            2'b01:   comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_DE;
            2'b10:   comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_HL;
            2'b11:   comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_AF;
            default: ;
          endcase
        end
      end //.

      // PUSH R16
      else if (comb_decoded_opcode[7:6] == 2'b11 && comb_decoded_opcode[3:0] == 4'b0101) begin

        if (m_cycle == 0) begin
          m_cycle_next = 1;
          // SP = SP - 1
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
          comb_bus_opcode_out = IDLE;

        end else if (m_cycle == 1) begin
          m_cycle_next = 2;
          // [SP] = R16_HIGH, SP = SP - 1
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_read_r = 1;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          case (comb_decoded_opcode[5:4])
            2'b00:   comb_rf_read_reg_r = B;
            2'b01:   comb_rf_read_reg_r = D;
            2'b10:   comb_rf_read_reg_r = H;
            2'b11:   comb_rf_read_reg_r = A;
            default: ;
          endcase
          // SP = SP - 1
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;

        end else if (m_cycle == 2) begin
          m_cycle_next = 3;
          // [SP] = R16_LOW
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          // Don't write SP, disable IDU
          comb_rf_write_rr = 0;
          comb_idu_en = 0;

          comb_rf_read_r = 1;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          case (comb_decoded_opcode[5:4])
            2'b00:   comb_rf_read_reg_r = C;
            2'b01:   comb_rf_read_reg_r = E;
            2'b10:   comb_rf_read_reg_r = L;
            2'b11:   comb_rf_read_reg_r = F;
            default: ;
          endcase

        end else begin
          // M4/M1: IF
          m_cycle_next = 0;
        end
      end  //.

      // RST n
      else if (comb_decoded_opcode[7:6] == 2'b11 && comb_decoded_opcode[2:0] == 3'b111) begin
        if (m_cycle == 0) begin
          // M2: SP = SP -1
          m_cycle_next = 1;
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
          comb_bus_opcode_out = IDLE;
        end else if (m_cycle == 1) begin
          // M3: [SP] = PCH, SP = SP - 1
          m_cycle_next = 2;
          // [SP] = PCH
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCH;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // SP = SP - 1
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 2) begin
          // M4: [SP] = PCL, PC = n
          m_cycle_next = 3;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          // Don't write SP, disable IDU
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCL;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // PC = n
          comb_rf_pc_rst = 1;
          comb_idu_en = 0;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LDH [a8], A
      else if (comb_decoded_opcode == 8'hE0) begin
        if (m_cycle == 0) begin
          // M2: read imm8 to Z, PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: [0xFF00 + Z] = A
          m_cycle_next = 2;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = A;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // Don't increment PC
          comb_idu_en = 0;
          // ADDR = 0xFF00 + Z
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = LDH_Z;
        end else begin
          // M4/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LDH [C], A
      else if (comb_decoded_opcode == 8'hE2) begin
        if (m_cycle == 0) begin
          // M2: [0xFF00 + C] = A
          m_cycle_next = 1;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = A;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // Don't increment PC
          comb_idu_en = 0;
          // ADDR = 0xFF00 + C
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = LDH_C;
        end else begin
          // M3/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LDH A, [a8]
      else if (comb_decoded_opcode == 8'hF0) begin
        if (m_cycle == 0) begin
          // M2: read imm8 to Z, PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: A = [0xFF00 + Z]
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          // ADDR = 0xFF00 + Z
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = LDH_Z;
        end else begin
          // M4/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LDH A, [C]
      else if (comb_decoded_opcode == 8'hF2) begin
        if (m_cycle == 0) begin
          // M2: A = [0xFF00 + C]
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          // ADDR = 0xFF00 + C
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = LDH_C;
        end else begin
          // M3/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LD [a16], A
      else if (comb_decoded_opcode == 8'hEA) begin
        if (m_cycle == 0) begin
          // M2: read imm16 to WZ, PC = PC + 2
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: read imm16 to WZ, PC = PC + 2
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else if (m_cycle == 2) begin
          // M4: [WZ] = A
          m_cycle_next = 3;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = A;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // Don't increment PC
          comb_idu_en = 0;
          // ADDR = WZ
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = WZ;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LD A, [a16]
      else if (comb_decoded_opcode == 8'hFA) begin
        if (m_cycle == 0) begin
          // M2: read imm16 to WZ, PC = PC + 2
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: read imm16 to WZ, PC = PC + 2
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else if (m_cycle == 2) begin
          // M4: A = [WZ]
          m_cycle_next = 3;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          // ADDR = WZ
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = WZ;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LD SP, HL
      else if (comb_decoded_opcode == 8'hF9) begin
        if (m_cycle == 0) begin
          m_cycle_next = 1;
          // SPL = L
          comb_alu_en = 1;
          comb_alu_op = PASS;
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = L;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = SPL;
          // don't increment PC
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
        end else begin
          // SPH = H

          m_cycle_next = 0;
          comb_alu_en = 1;
          comb_alu_op = PASS;
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = H;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = SPH;
        end
      end //.

      // JR imm8
      else if (comb_decoded_opcode == 8'h18) begin
        if (m_cycle == 0) begin
          // M2 Z = e8
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;

          comb_rf_write_rr = 0;  // don't advance PC

        end else if (m_cycle == 1) begin
          // M3: PC = PC + imm8
          m_cycle_next = 2;
          comb_bus_opcode_out = IDLE;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
          // PC = PC + imm8
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = PC;
          comb_rf_write_rr = 1;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          comb_idu_en = 1;
          comb_idu_op = IDU_ADD_S8;
        end else begin
          // M4/M1: IF
          m_cycle_next = 0;
        end
      end  //.

      // JR cc, e
      else if (comb_decoded_opcode[7:5] == 2'b001 && comb_decoded_opcode[2:0] == 3'b000) begin
        if (m_cycle == 0) begin
          // M2 Z = e8
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          comb_rf_write_rr = 0;  // don't advance PC

          // Do we jump ?
          case (comb_decoded_opcode[4:3])
            2'b00:   m_cycle_next = (~rf_flags.Z) ? 1 : 2;
            2'b01:   m_cycle_next = (rf_flags.Z) ? 1 : 2;
            2'b10:   m_cycle_next = (~rf_flags.C) ? 1 : 2;
            2'b11:   m_cycle_next = (rf_flags.C) ? 1 : 2;
            default: m_cycle_next = 2;
          endcase
        end else if (m_cycle == 1) begin
          // M3: PC = PC + imm8
          m_cycle_next = 2;
          comb_bus_opcode_out = IDLE;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
          // PC = PC + imm8
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = PC;
          comb_rf_write_rr = 1;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          comb_idu_en = 1;
          comb_idu_op = IDU_ADD_S8;
        end else begin
          // M4(or M3)/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // RET/RETI
      else if (comb_decoded_opcode[7:5] == 3'b110 && comb_decoded_opcode[3:0] == 4'b1001) begin
        if (m_cycle == 0) begin
          // M2: Z = [SP], SP = SP + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          // SP = SP + 1
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 1) begin
          m_cycle_next = 2;
          // M3: W = [SP], SP = SP + 1
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 2) begin
          // M4: PC = WZ
          m_cycle_next = 3;
          comb_bus_opcode_out = IDLE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
          // don't increment PC, disable IDU
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
          // If RETI, also set IME = 1
          // TODO: Enable IME
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end

      end //.

      // RET CC
      else if (comb_decoded_opcode[7:5] == 3'b110 && comb_decoded_opcode[2:0] == 3'b000) begin

        if (m_cycle == 0) begin
          // M2: CC check
          case (comb_decoded_opcode[4:3])
            2'b00:   m_cycle_next = (~rf_flags.Z) ? 1 : 4;
            2'b01:   m_cycle_next = (rf_flags.Z) ? 1 : 4;
            2'b10:   m_cycle_next = (~rf_flags.C) ? 1 : 4;
            2'b11:   m_cycle_next = (rf_flags.C) ? 1 : 4;
            default: m_cycle_next = 4;
          endcase
          // Don't increment PC
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;

        end else if (m_cycle == 1) begin
          // M3: If condition is true, Z = [SP], SP = SP + 1
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
          // SP = SP + 1
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 2) begin
          // M4: If condition is true, W = [SP], SP = SP + 1
          m_cycle_next = 3;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 3) begin
          // M5: If condition is true, PC = WZ
          m_cycle_next = 4;
          comb_bus_opcode_out = IDLE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
          // don't increment PC, disable IDU
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end  //.

      // JP CC, a16
      else if (comb_decoded_opcode[7:5] == 3'b110 && comb_decoded_opcode[2:0] == 3'b010) begin
        if (m_cycle == 0) begin
          // M2: Z = [PC], PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: W = [PC], PC = PC + 1, cc check
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;

          case (comb_decoded_opcode[4:3])
            2'b00:   m_cycle_next = (~rf_flags.Z) ? 2 : 4;
            2'b01:   m_cycle_next = (rf_flags.Z) ? 2 : 4;
            2'b10:   m_cycle_next = (~rf_flags.C) ? 2 : 4;
            2'b11:   m_cycle_next = (rf_flags.C) ? 2 : 4;
            default: m_cycle_next = 4;
          endcase

        end else if (m_cycle == 2) begin
          // M4: If condition is true, PC = WZ
          m_cycle_next = 3;
          comb_bus_opcode_out = IDLE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
          // don't increment PC, disable IDU
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;

        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.


      // JP a16
      else if (comb_decoded_opcode == 8'hC3) begin
        if (m_cycle == 0) begin
          // M2: Z = [PC], PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: W = [PC], PC = PC + 1
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else if (m_cycle == 2) begin
          // M4: PC = WZ
          m_cycle_next = 3;
          comb_bus_opcode_out = IDLE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
          // don't increment PC, disable IDU
          comb_idu_en = 0;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // JP HL
      else if (comb_decoded_opcode == 8'hE9) begin
        // Fetch form HL, and PC = HL + 1
        comb_rf_read_rr = 1;
        comb_rf_read_reg_rr = HL;
        comb_rf_write_rr = 1;
        comb_rf_write_reg_rr = PC;
      end  //.

      // CALL a16
      else if (comb_decoded_opcode == 8'hCD) begin
        if (m_cycle == 0) begin
          // M2: Z = [PC], PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: W = [PC], PC = PC + 1
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;
        end else if (m_cycle == 2) begin
          // M4 SP = SP - 1
          m_cycle_next = 3;
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
          comb_bus_opcode_out = IDLE;
        end else if (m_cycle == 3) begin
          // M5: [SP] = PCH, SP = SP - 1
          m_cycle_next = 4;
          // [SP] = PCH
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCH;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // SP = SP - 1
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 4) begin
          // M6: [SP] = PCL, PC = WZ
          m_cycle_next = 5;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          // Don't write SP, disable IDU
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCL;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
        end else begin
          // M7/M1: IF
          m_cycle_next = 0;
        end
      end //..

      // CALL CC, a16
      else if (comb_decoded_opcode[7:5] == 3'b110 && comb_decoded_opcode[2:0] == 3'b100) begin
        if (m_cycle == 0) begin
          // M2: Z = [PC], PC = PC + 1
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;
        end else if (m_cycle == 1) begin
          // M3: W = [PC], PC = PC + 1, cc check
          m_cycle_next = 2;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = W;

          case (comb_decoded_opcode[4:3])
            2'b00:   m_cycle_next = (~rf_flags.Z) ? 2 : 6;
            2'b01:   m_cycle_next = (rf_flags.Z) ? 2 : 6;
            2'b10:   m_cycle_next = (~rf_flags.C) ? 2 : 6;
            2'b11:   m_cycle_next = (rf_flags.C) ? 2 : 6;
            default: m_cycle_next = 6;
          endcase

        end else if (m_cycle == 2) begin
          // M4: If condition is true, SP = SP - 1
          m_cycle_next = 3;
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
          comb_bus_opcode_out = IDLE;

        end else if (m_cycle == 3) begin
          // M5: If condition is true, [SP] = PCH, SP = SP - 1
          m_cycle_next = 4;
          // [SP] = PCH
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCH;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // SP = SP - 1
          comb_idu_en = 1;
          comb_idu_op = IDU_DEC;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
        end else if (m_cycle == 4) begin
          // M6: If condition is true, [SP] = PCL, PC = WZ
          m_cycle_next = 5;
          comb_bus_opcode_out = WRITE;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          // Don't write SP, disable IDU
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = PCL;
          comb_data_out_ctrl = DOUT_FROM_REG_FILE;
          // PC = WZ
          comb_rf_copy_wz_to_rr_op = COPY_WZ_TO_PC;
          comb_rf_copy_wz_to_rr_en = 1;
        end else begin
          // M7/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // ADD SP, e8
      else if (comb_decoded_opcode == 8'hE8) begin
        // bruhh ...
        // We will do this one a it diffrently
        // We will cacluate the flags using the ALU and the actual result using the IDU
        // M2: Read e8 to Z
        // M3: IDU: (SP + Z), ALU: SPL + Z, write
        // M4: Stall
        // M5: IF
        if (m_cycle == 0) begin
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;

        end else if (m_cycle == 1) begin
          // M3. IDU: SP = SP + Z, ALU: SPL + Z
          m_cycle_next = 2;
          comb_bus_opcode_out = IDLE;
          // SP +(IDU_ADD_S8)+ Z
          comb_idu_en = 1;
          comb_idu_op = IDU_ADD_S8;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = SP;
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          // Calculate flags using ALU
          comb_alu_en = 1;
          comb_alu_op = SP_ADJ;
          comb_alu_src_a_select = ALU_SRC_A_REG;  // Z already read
          comb_alu_src_b_select = ALU_SRC_B_RR_LOW;  // SPL on 16bit bus
          comb_rf_flags_we = 1;  // F = 0,0,H,C

        end else if (m_cycle == 2) begin
          // M4: Stall
          m_cycle_next = 3;
          comb_bus_opcode_out = IDLE;
          comb_rf_read_rr = 0;
          comb_rf_write_rr = 0;
          comb_idu_en = 0;
        end else begin
          // M5/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // LD HL, SP + e8
      else if (comb_decoded_opcode == 8'hF8) begin
        if (m_cycle == 0) begin
          // M2: Read e8 to Z
          m_cycle_next = 1;
          comb_bus_opcode_out = READ;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = Z;

        end else if (m_cycle == 1) begin
          // M3. IDU: HL = (SP + Z), ALU: SPL + Z for flags
          m_cycle_next = 2;
          comb_bus_opcode_out = IDLE;
          // HL = SP + Z
          comb_idu_en = 1;
          comb_idu_op = IDU_ADD_S8;
          comb_rf_read_rr = 1;
          comb_rf_read_reg_rr = SP;
          // Write result to HL
          comb_rf_write_rr = 1;
          comb_rf_write_reg_rr = HL;
          // Get e8
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = Z;
          // Calculate result using ALU
          comb_alu_en = 1;
          comb_alu_op = SP_ADJ;
          comb_alu_src_a_select = ALU_SRC_A_REG;  // Z already read
          comb_alu_src_b_select = ALU_SRC_B_RR_LOW;  // SPL on 16bit bus
          comb_rf_flags_we = 1;  // F = 0,0,H,C

        end else begin
          // M4/M1: IF
          m_cycle_next = 0;
        end
      end //.

      // RLCA, RRCA, RLA, RRA, DAA, CPL, SCF, CCF
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[2:0] == 3'b111) begin
        comb_alu_en = 1;
        comb_alu_op = alu_op_t'({2'b10, comb_decoded_opcode[5:3]});
        comb_rf_read_r = (comb_decoded_opcode[4:3] < 5);  // CPL, SCF, CCF don't neet A reg;
        comb_rf_read_reg_r = A;
        comb_rf_write_r = (comb_decoded_opcode[4:3] < 5);  // CPL, SCF, CCF don't neet A reg;
        comb_rf_write_reg_r = A;
        comb_rf_flags_we = 1;
      end //.

      // CB prefix
      else if (comb_decoded_opcode == 8'hCB) begin
        if (m_cycle == 0) begin
          m_cycle_next = 1;
          comb_bus_opcode_out = IF_CB;
        end else begin
          // TODO
        end
      end

    end
  end

  always @(posedge clk) begin

    if (rst) m_cycle <= 0;
    else m_cycle <= m_cycle_next;
  end


  always @(*) begin
    decoded_opcode <= comb_decoded_opcode;
    bus_opcode_out <= comb_bus_opcode_out;

    idu_op <= comb_idu_op;
    idu_en <= comb_idu_en;

    rf_read_r <= comb_rf_read_r;
    rf_read_reg_r <= comb_rf_read_reg_r;
    rf_read_rr <= comb_rf_read_rr;
    rf_read_reg_rr <= comb_rf_read_reg_rr;
    rf_write_r <= comb_rf_write_r;
    rf_write_reg_r <= comb_rf_write_reg_r;
    rf_write_rr <= comb_rf_write_rr;
    rf_write_reg_rr <= comb_rf_write_reg_rr;
    rf_copy_wz_to_rr_op <= comb_rf_copy_wz_to_rr_op;
    rf_copy_wz_to_rr_en <= comb_rf_copy_wz_to_rr_en;
    rf_pc_rst <= comb_rf_pc_rst;
    rf_flags_we <= comb_rf_flags_we;
    rf_flag_mask_n <= comb_rf_flag_mask_n;

    alu_en <= comb_alu_en;
    alu_op <= comb_alu_op;
    alu_bit_idx <= comb_alu_bit_idx;
    alu_src_a_select <= comb_alu_src_a_select;
    alu_src_b_select <= comb_alu_src_b_select;

    data_out_ctrl <= comb_data_out_ctrl;
  end

endmodule
