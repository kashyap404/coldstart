// Control: sanitizes cnt before use, so the property is init-independent.
// Expected: PASS with init and without.
`include "fpga_init.svh"
module robust_counter(input logic clk, input logic en);
  logic [3:0] cnt `INIT(4'd0);

  wire [3:0] safe = (cnt > 4'd9) ? 4'd0 : cnt;

  always_ff @(posedge clk)
    if (en) cnt <= (safe == 4'd9) ? 4'd0 : safe + 4'd1;

  assert property (@(posedge clk) safe <= 4'd9);
endmodule
