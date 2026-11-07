// Five valid stages, no reset. `seen_in` is checker state, so a token cannot
// appear at the output before any input has been accepted.
// Expected: PASS with init, FAIL without.
`include "fpga_init.svh"
module pipe5(
  input  logic clk,
  input  logic in_valid,
  output logic out_valid
);
  logic [4:0] v `INIT(5'b0);

  always_ff @(posedge clk)
    v <= {v[3:0], in_valid};

  assign out_valid = v[4];

  logic seen_in = 1'b0;

  always_ff @(posedge clk)
    seen_in <= seen_in | in_valid;

  assert property (@(posedge clk) !out_valid || seen_in);
endmodule
