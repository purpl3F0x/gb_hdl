package cpu_pkg;
  typedef enum logic [2:0] {
    B = 3'b000,
    C = 3'b001,
    D = 3'b010,
    E = 3'b011,
    H = 3'b100,
    L = 3'b101,
    F = 3'b110,
    A = 3'b111
  } register_n_t;

  typedef enum logic [2:0] {
    BC = 3'b000,
    DE = 3'b001,
    HL = 3'b010,
    SP = 3'b011,
    PC = 3'b100
  } register_nn_t;

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
