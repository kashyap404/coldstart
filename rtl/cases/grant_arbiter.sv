// No reset. `seen_bad` is a sticky checker so a clocked assertion can see the
// one-cycle pre-edge collision. Property: !seen_bad.
// Expected: PASS with init, FAIL without.
`include "fpga_init.svh"
module grant_arbiter(input logic clk, input logic r0, input logic r1);
  logic g0   `INIT(1'b0);
  logic g1   `INIT(1'b0);
  logic last `INIT(1'b0);   // 1 = g0 was served last

  wire n_g0 = r0 && !(r1 && last);
  wire n_g1 = r1 && !n_g0;

  logic seen_bad = 1'b0;

  always_ff @(posedge clk) begin
    g0 <= n_g0;
    g1 <= n_g1;
    if (n_g0)      last <= 1'b1;
    else if (n_g1) last <= 1'b0;
    seen_bad <= seen_bad | (g0 && g1);
  end

  assert property (@(posedge clk) !seen_bad);
endmodule
