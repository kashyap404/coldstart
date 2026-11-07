// No reset; relies on power-up 0. Property: cnt <= 9.
// Expected: PASS with init, FAIL without.
`include "fpga_init.svh"
module decade_counter(input logic clk, input logic en);
  logic [3:0] cnt `INIT(4'd0);

  always_ff @(posedge clk)
    if (en) cnt <= (cnt == 4'd9) ? 4'd0 : cnt + 4'd1;

  assert property (@(posedge clk) cnt <= 4'd9);
endmodule
