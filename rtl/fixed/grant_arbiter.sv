// Fixed arbiter: the reset clears both grants and the sticky checker.
module grant_arbiter_fixed(input logic clk, input logic r0, input logic r1);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic g0;
  logic g1;
  logic last;
  logic seen_bad;

  wire n_g0 = r0 && !(r1 && last);
  wire n_g1 = r1 && !n_g0;

  always_ff @(posedge clk) begin
    if (rst) begin
      g0       <= 1'b0;
      g1       <= 1'b0;
      last     <= 1'b0;
      seen_bad <= 1'b0;
    end else begin
      g0 <= n_g0;
      g1 <= n_g1;
      if (n_g0)      last <= 1'b1;
      else if (n_g1) last <= 1'b0;
      seen_bad <= seen_bad | (g0 && g1);
    end
  end

  assert property (@(posedge clk) !seen_bad);
endmodule
