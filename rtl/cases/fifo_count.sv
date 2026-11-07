// Pointers plus a redundant occupancy counter. Property: count == wr - rd.
// Expected: PASS with init, FAIL without.
// if/else avoids `case`, which imports as comb.icmp ceq and breaks SMT lowering.
`include "fpga_init.svh"
module fifo_count(input logic clk, input logic push, input logic pop);
  logic [2:0] wr_ptr `INIT(3'd0);
  logic [2:0] rd_ptr `INIT(3'd0);
  logic [2:0] count  `INIT(3'd0);

  wire do_push = push && (count != 3'd4);
  wire do_pop  = pop  && (count != 3'd0);

  always_ff @(posedge clk) begin
    if (do_push) wr_ptr <= wr_ptr + 3'd1;
    if (do_pop)  rd_ptr <= rd_ptr + 3'd1;

    if (do_push && !do_pop)
      count <= count + 3'd1;
    else if (!do_push && do_pop)
      count <= count - 3'd1;
  end

  assert property (@(posedge clk) count == (wr_ptr - rd_ptr));
endmodule
