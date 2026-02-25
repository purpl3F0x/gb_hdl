import alu_pkg::*;
import cpu_pkg::*;

module control (
    input clk,
    input rst,

    input [7:0] next_opcode,


    output bus_opcode_t bus_opcode_out,

    // IDU control signals
    output reg idu_op,
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
    output reg data_in_reg_wr,
    output data_out_ctrl_t data_out_ctrl
);

  reg [7:0] decoded_opcode;

  reg [1:0] m_cycle, m_cycle_next;

  logic [7:0] comb_decoded_opcode;
  bus_opcode_t comb_bus_opcode_out;
  reg comb_idu_op;
  reg comb_idu_en;
  reg comb_rf_read_r;
  register_n_t comb_rf_read_reg_r;
  reg comb_rf_write_r;
  register_n_t comb_rf_write_reg_r;
  reg comb_rf_read_rr;
  register_nn_t comb_rf_read_reg_rr;
  reg comb_rf_write_rr;
  register_nn_t comb_rf_write_reg_rr;
  reg comb_rf_flags_we;
  flags_t comb_rf_flag_mask_n;

  reg comb_alu_en;
  alu_op_t comb_alu_op;
  reg [2:0] comb_alu_bit_idx;
  alu_src_a_select_t comb_alu_src_a_select;
  alu_src_b_select_t comb_alu_src_b_select;

  reg comb_data_in_reg_wr;
  data_out_ctrl_t comb_data_out_ctrl;


  always_comb begin
    comb_decoded_opcode = 8'h00;
    comb_bus_opcode_out = IDLE;
    comb_idu_op = 0;
    comb_idu_en = 0;
    comb_rf_read_r = 0;
    comb_rf_read_reg_r = A;
    comb_rf_write_r = 0;
    comb_rf_write_reg_r = A;
    comb_rf_read_rr = 0;
    comb_rf_read_reg_rr = BC;
    comb_rf_write_rr = 0;
    comb_rf_write_reg_rr = BC;
    comb_rf_flags_we = 0;
    comb_rf_flag_mask_n = 4'b0000;

    comb_alu_en = 0;
    comb_alu_op = ADD;
    comb_alu_bit_idx = 3'b000;
    comb_alu_src_a_select = ALU_SRC_A_REG;
    comb_alu_src_b_select = ALU_SRC_B_ONE;

    comb_data_in_reg_wr = 0;

    comb_data_out_ctrl = DOUT_FROM_ALU_RES;

    if (rst) begin
      m_cycle_next = 0;
    end

    if (!rst) begin
      comb_decoded_opcode = (m_cycle == 0) ? next_opcode : decoded_opcode;
      comb_bus_opcode_out = IF;
      comb_idu_op = 0;
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

      // 16-bit INC/DEC
      else if (comb_decoded_opcode[7:6] == 2'b00 && comb_decoded_opcode[2:0] == 3'b011) begin

        if (m_cycle == 0) begin
          // M2: INC/DEC RR
          m_cycle_next = 1;
          comb_bus_opcode_out = IDLE;
          comb_idu_en = 1;
          comb_idu_op = (comb_decoded_opcode[3] == 0 ? 0 : 1);
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
            comb_data_in_reg_wr = 1;

          end else if (m_cycle == 1) begin
            // M2: ALU + WRITE_BACK
            m_cycle_next = 2;

            comb_bus_opcode_out = WRITE;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;

            comb_alu_en = 1;
            comb_alu_src_a_select = ALU_SRC_A_TMP;
            comb_alu_src_b_select = ALU_SRC_B_ONE;
            comb_alu_op = alu_op_t'(comb_decoded_opcode[0] == 3'b000 ? ADD : SUB);

          end else if (m_cycle == 2) begin
            // M4/M1: IF
            m_cycle_next = 0;
            comb_idu_en = 1;
            comb_rf_read_rr = 1;
            comb_rf_write_rr = 1;
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
      // TODO: HALT should be before that

      // 8-bit reg2reg mem2reg, reg2mem LD
      else if (comb_decoded_opcode[7:6] == 2'b01) begin

        if (comb_decoded_opcode[2:0] == 3'b110) begin  // LD R, [HL]

          if (m_cycle == 0) begin  // M2 read to tmp
            m_cycle_next = 1;
            // Skip PC+1
            idu_en = 0;
            comb_idu_en = 0;
            comb_rf_write_rr = 0;

            comb_bus_opcode_out = READ;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_data_in_reg_wr = 1;
          end else begin  // M3/M1 IF
            m_cycle_next = 0;
            // R = TMP + 0
            comb_rf_write_r = 1;
            comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
            comb_alu_src_a_select = ALU_SRC_A_TMP;
            comb_alu_src_b_select = ALU_SRC_B_ZERO;
            comb_alu_op = ADD;
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
            idu_en = 0;
            comb_idu_en = 0;
            comb_rf_write_rr = 0;

          end else begin  // M3 / M1 nothing happens just IF
            m_cycle_next = 0;
            // PC = PC + 1
          end

        end else begin  // LD R, R'
          // R = R' + 0
          comb_rf_read_r = 1;
          comb_rf_read_reg_r = register_n_t'(comb_decoded_opcode[2:0]);
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = register_n_t'(comb_decoded_opcode[5:3]);
          comb_alu_src_a_select = ALU_SRC_A_REG;
          comb_alu_src_b_select = ALU_SRC_B_ZERO;
          comb_alu_op = ADD;
          comb_alu_en = 1;
          comb_rf_flags_we = 0;
        end

      end //.
      // 8-bit ALU OP reg2reg, mem2reg
      else if (comb_decoded_opcode[7:6] == 2'b10) begin
        comb_alu_src_a_select = ALU_SRC_A_A;

        // From HL
        if (comb_decoded_opcode[2:0] == 3'b110) begin
          if (m_cycle == 0) begin  // M2: Read [HL]

            m_cycle_next = 1;
            // Don't Increment PC
            comb_idu_en = 0;
            comb_rf_read_rr = 0;
            comb_rf_write_rr = 0;

            comb_bus_opcode_out = READ;
            comb_rf_read_rr = 1;
            comb_rf_read_reg_rr = HL;
            comb_data_in_reg_wr = 1;

          end else begin  // M3: ALU OP + IF
            m_cycle_next = 0;
            // Do the ALU operation
            comb_alu_src_b_select = ALU_SRC_B_TMP;
            comb_alu_en = 1;
            comb_alu_op = alu_op_t'({2'b00, comb_decoded_opcode[5:3]});
            // Write Result to A and update flags
            comb_rf_write_r = 1;
            comb_rf_write_reg_r = A;
            comb_rf_flags_we = 1;
          end
        end // if from [HL]
        else begin
          comb_rf_write_r = 1;
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
          comb_data_in_reg_wr = 1;

        end else begin
          //  M3/M1
          m_cycle_next = 0;
          comb_rf_write_r = 1;
          comb_rf_write_reg_r = A;
          comb_alu_src_a_select = ALU_SRC_A_A;
          comb_alu_src_b_select = ALU_SRC_B_TMP;
          comb_alu_op = alu_op_t'({2'b00, comb_decoded_opcode[5:3]});
          comb_alu_en = 1;
          comb_rf_flags_we = 1;

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
    rf_flags_we <= comb_rf_flags_we;
    rf_flag_mask_n <= comb_rf_flag_mask_n;

    alu_en <= comb_alu_en;
    alu_op <= comb_alu_op;
    alu_bit_idx <= comb_alu_bit_idx;
    alu_src_a_select <= comb_alu_src_a_select;
    alu_src_b_select <= comb_alu_src_b_select;
    data_in_reg_wr <= comb_data_in_reg_wr;

    data_out_ctrl <= comb_data_out_ctrl;
  end

endmodule
