
module idu (
    input en,
    input op,
    input [15:0] data_in,
    output reg [15:0] data_out
);

  always_comb begin
    data_out = 16'h0000;

    if (en) begin
      case (op)
        0: data_out = data_in + 1;
        1: data_out = data_in - 1;
        default: data_out = 16'h0000;
      endcase
    end
  end

endmodule
