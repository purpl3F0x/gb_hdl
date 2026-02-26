package cpu_pkg;
  typedef enum logic [3:0] {
    B = 4'b0000,
    C = 4'b0001,
    D = 4'b0010,
    E = 4'b0011,
    H = 4'b0100,
    L = 4'b0101,
    Z = 4'b0110,
    A = 4'b0111,
    SPH = 4'b1000,
    SPL = 4'b1001,
    W = 4'b1010
  } register_n_t;

  typedef enum logic [2:0] {
    BC = 3'b000,
    DE = 3'b001,
    HL = 3'b010,
    SP = 3'b011,
    PC = 3'b100,
    WZ = 3'b101
  } register_nn_t;

  typedef enum logic [2:0] {
    NO_COPY = 3'b000,
    COPY_WZ_TO_BC = 3'b100,
    COPY_WZ_TO_DE = 3'b101,
    COPY_WZ_TO_HL = 3'b110,
    COPY_WZ_TO_SP = 3'b111
  } copy_wz_to_rr_op_t;

  typedef enum logic [1:0] {
    IDLE,
    IF,
    WRITE,
    READ
  } bus_opcode_t;

  typedef enum logic {
    DOUT_FROM_ALU_RES,
    DOUT_FROM_REG_FILE
  } data_out_ctrl_t;

  typedef enum logic [1:0] {
    ALU_SRC_A_A,
    ALU_SRC_A_REG,
    ALU_SRC_A_TMP
  } alu_src_a_select_t;

  typedef enum logic [1:0] {
    ALU_SRC_B_REG,
    ALU_SRC_B_TMP,
    ALU_SRC_B_ZERO,
    ALU_SRC_B_ONE
  } alu_src_b_select_t;

endpackage
