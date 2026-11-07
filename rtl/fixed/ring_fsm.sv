// Fixed ring FSM: the reset forces the legal one-hot start state.
module ring_fsm_fixed(input logic clk, input logic adv);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic [2:0] st;

  always_ff @(posedge clk)
    if (rst)
      st <= 3'b001;
    else if (adv)
      st <= {st[1:0], st[2]};

  assert property (@(posedge clk)
    st == 3'b001 || st == 3'b010 || st == 3'b100);
endmodule
