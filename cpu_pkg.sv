package cpu_pkg;
  typedef enum logic [3:0] {
    B   = 4'b0000,
    C   = 4'b0001,
    D   = 4'b0010,
    E   = 4'b0011,
    H   = 4'b0100,
    L   = 4'b0101,
    Z   = 4'b0110,
    A   = 4'b0111,
    SPH = 4'b1000,
    SPL = 4'b1001,
    W   = 4'b1010,
    F   = 4'b1011
  } register_n_t;

  typedef enum logic [2:0] {
    BC = 3'b000,
    DE = 3'b001,
    HL = 3'b010,
    SP = 3'b011,
    PC = 3'b100,
    WZ = 3'b101,
    LDH_Z = 3'b110,  // (0xFF00 + Z)
    LDH_C = 3'b111  // (0xFF00 + C)
  } register_nn_t;

  typedef enum logic [2:0] {  // TODO: this needs to be sperated with enable signal
    NO_COPY = 3'b000,
    COPY_WZ_TO_BC = 3'b100,
    COPY_WZ_TO_DE = 3'b101,
    COPY_WZ_TO_HL = 3'b110,
    COPY_WZ_TO_SP = 3'b111,
    COPY_WZ_TO_AF = 3'b001
  } copy_wz_to_rr_op_t;

  typedef enum logic [2:0] {
    IDLE,
    IF,
    WRITE,
    READ,
    IF_CB
  } bus_opcode_t;

  typedef enum logic {
    DOUT_FROM_ALU_RES,
    DOUT_FROM_REG_FILE
  } data_out_ctrl_t;

  typedef enum logic [1:0] {
    ALU_SRC_A_A,
    ALU_SRC_A_REG,
    ALU_SRC_A_L,
    ALU_SRC_A_H
  } alu_src_a_select_t;

  typedef enum logic [1:0] {
    ALU_SRC_B_REG,
    ALU_SRC_B_ZERO,
    ALU_SRC_B_ONE
  } alu_src_b_select_t;

endpackage
