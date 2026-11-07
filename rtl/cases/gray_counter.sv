// Registered Gray copy of a binary counter. Property: gray == enc(bin).
// Expected: PASS with init, FAIL without.
`include "fpga_init.svh"
module gray_counter(input logic clk, input logic en);
  logic [2:0] bin  `INIT(3'd0);
  logic [2:0] gray `INIT(3'd0);

  wire [2:0] bin_n = bin + 3'd1;

  always_ff @(posedge clk)
    if (en) begin
      bin  <= bin_n;
      gray <= bin_n ^ (bin_n >> 1);
    end

  assert property (@(posedge clk) gray == (bin ^ (bin >> 1)));
endmodule
