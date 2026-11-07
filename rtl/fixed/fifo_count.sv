// Fixed FIFO bookkeeping: the reset clears pointers and count together.
module fifo_count_fixed(input logic clk, input logic push, input logic pop);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic [2:0] wr_ptr;
  logic [2:0] rd_ptr;
  logic [2:0] count;

  wire do_push = push && (count != 3'd4);
  wire do_pop  = pop  && (count != 3'd0);

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr <= 3'd0;
      rd_ptr <= 3'd0;
      count  <= 3'd0;
    end else begin
      if (do_push) wr_ptr <= wr_ptr + 3'd1;
      if (do_pop)  rd_ptr <= rd_ptr + 3'd1;

      if (do_push && !do_pop)
        count <= count + 3'd1;
      else if (!do_push && do_pop)
        count <= count - 3'd1;
    end
  end

  assert property (@(posedge clk) count == (wr_ptr - rd_ptr));
endmodule
