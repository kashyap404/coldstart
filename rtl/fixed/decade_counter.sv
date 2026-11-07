// Fixed decade counter: power-on reset establishes a known count.
module decade_counter_fixed(input logic clk, input logic en);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic [3:0] cnt;

  always_ff @(posedge clk)
    if (rst)
      cnt <= 4'd0;
    else if (en)
      cnt <= (cnt == 4'd9) ? 4'd0 : cnt + 4'd1;

  assert property (@(posedge clk) cnt <= 4'd9);
endmodule
