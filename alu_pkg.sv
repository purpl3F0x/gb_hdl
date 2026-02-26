`timescale 1ns / 1ps


package alu_pkg;
  typedef struct packed {
    logic Z;  // Zero Flag
    logic N;  // Subtract Flag
    logic H;  // Half Carry Flag
    logic C;  // Carry Flag
  } flags_t;

  typedef enum logic [4:0] {
    // ADD/AND/OR/XOR etc.. - (00)
    ADD  = 5'b00000,
    ADC  = 5'b00001,
    SUB  = 5'b00010,
    SBC  = 5'b00011,
    AND  = 5'b00100,
    XOR  = 5'b00101,
    OR   = 5'b00110,
    CP   = 5'b00111,
    // SHIFT / ROT - (01)
    RLC  = 5'b01000,
    RRC  = 5'b01001,
    RL   = 5'b01010,
    RR   = 5'b01011,
    SLA  = 5'b01100,
    SRA  = 5'b01101,
    SWAP = 5'b01110,
    SRL  = 5'b01111,
    // SPECIAL - (10)
    // LF   = 5'b10000,  // Load Flags
    // SF   = 5'b10010,  // Save Flags
    RLCA = 5'b10000,
    RRCA = 5'b10001,
    RLA  = 5'b10010,
    RRA  = 5'b10011,
    DAA  = 5'b10100,
    CPL  = 5'b10101,
    SCF  = 5'b10110,
    CCF  = 5'b10111,
    // BIT OPS - (11)
    BIT  = 5'b11101,
    RES  = 5'b11110,
    SET  = 5'b11111
  } alu_op_t;
endpackage
