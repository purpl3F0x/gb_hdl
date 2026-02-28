
import cpu_pkg::*;

module idu (
    input en,
    input idu_op_t op,
    input [15:0] data_in,
    input [7:0] e8,
    output reg [15:0] data_out
);

  always_comb begin
    data_out = 16'h0000;

    if (en) begin
      case (op)
        IDU_INC: data_out = data_in + 1;
        IDU_DEC: data_out = data_in - 1;
        IDU_PASS: data_out = data_in;
        IDU_JR_ADJ: data_out = data_in + {{8{e8[7]}}, e8};
        default: data_out = 16'h0000;
      endcase
    end
  end

endmodule
