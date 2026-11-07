// No reset; relies on power-up 3'b001. Property: state is exactly one-hot.
// Expected: PASS with init, FAIL without.
`include "fpga_init.svh"
module ring_fsm(input logic clk, input logic adv);
  logic [2:0] st `INIT(3'b001);

  always_ff @(posedge clk)
    if (adv) st <= {st[1:0], st[2]};

  assert property (@(posedge clk)
    st == 3'b001 || st == 3'b010 || st == 3'b100);
endmodule
