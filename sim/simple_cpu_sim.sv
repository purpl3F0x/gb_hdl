`timescale 1ns / 1ps

// Simple testbench wrapper for `cpu`.
// - Provides clock/reset ports for cocotb
// - Implements a memory *behaviour* where `data_in = addr_out + 0x42` whenever `rd_en` is asserted


module simple_cpu_sim();

  logic clk = 0;
  logic rst = 0;

  logic [7:0] data_in;
  wire rd_en;
  wire wr_en;
  wire [15:0] addr_out;
  logic [7:0] data_out;

  cpu uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .addr_out(addr_out),
        .data_out(data_out)
      );

  initial
  begin
    clk = 1;
    forever
      #5 clk = ~clk;
  end

    reg [7:0] mem [65536];

    initial begin
    integer i;
    for (i = 0; i < 65536; i++) begin
      mem[i] = 0;
    end

    mem[0] = 8'h71;
    // mem[1] = 8'h02;

    mem[16'h1234] = 8'h12;
  end


  initial
  begin
    $dumpfile("simulation.vcd");
    $dumpvars(0);

    rst = 1;

    #20;
    rst = 0;
    uut.reg_file.HL_reg = 16'h1234;
    uut.reg_file.BC_reg = 16'h1234;
    uut.reg_file.AF_reg = 16'h1100;

    #10;

    #40 $finish;
  end



always_ff @(posedge clk)
   begin
      if (wr_en) begin
         mem[addr_out] <= data_out;
      end
   end


   always_comb
   begin
      if (rd_en) begin
         data_in = mem[addr_out];
      end else begin
         data_in = 16'h0000;
      end
   end
endmodule
