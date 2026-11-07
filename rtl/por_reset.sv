// Two-cycle power-on reset for the fixed designs. The counter is initialized
// in both runs; the datapath it resets is still arbitrary under -DNO_INIT.
module por_reset(input logic clk, output logic rst);
  logic [1:0] cnt = 2'd0;

  assign rst = (cnt != 2'd2);

  always_ff @(posedge clk)
    if (rst)
      cnt <= cnt + 2'd1;
endmodule
