`timescale 1ns / 1ps

interface bus_if #(
    parameter unsigned ADDR_WIDTH = 16
);
  logic [ADDR_WIDTH-1:0] addr;  // Address width
  logic [           7:0] dout;  // Data from CPU (Write)
  /* verilator lint_off UNOPTFLAT */
  logic [           7:0] din;  // Data to CPU (Read)
  /* verilator lint_on UNOPTFLAT */
  logic                  we;  // Write Enable
  logic                  re;  // Read Enable

  // Modport for the CPU (The Master)
  modport master(output addr, dout, we, re, input din);

  // Modport for Peripherals (The Slaves)
  modport slave(input addr, dout, we, re, output din);
endinterface


package boy_pkg;

endpackage
