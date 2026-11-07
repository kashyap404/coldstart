// Fixed Gray counter: the reset clears bin and gray together.
module gray_counter_fixed(input logic clk, input logic en);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic [2:0] bin;
  logic [2:0] gray;

  wire [2:0] bin_n = bin + 3'd1;

  always_ff @(posedge clk)
    if (rst) begin
      bin  <= 3'd0;
      gray <= 3'd0;
    end else if (en) begin
      bin  <= bin_n;
      gray <= bin_n ^ (bin_n >> 1);
    end

  assert property (@(posedge clk) gray == (bin ^ (bin >> 1)));
endmodule
