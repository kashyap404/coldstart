// Fixed pipeline: the reset clears the valid chain before use.
module pipe5_fixed(
  input  logic clk,
  input  logic in_valid,
  output logic out_valid
);
  wire rst;
  por_reset por(.clk(clk), .rst(rst));

  logic [4:0] v;
  logic seen_in;

  always_ff @(posedge clk) begin
    if (rst) begin
      v       <= 5'b0;
      seen_in <= 1'b0;
    end else begin
      v       <= {v[3:0], in_valid};
      seen_in <= seen_in | in_valid;
    end
  end

  assign out_valid = v[4];

  assert property (@(posedge clk) !out_valid || seen_in);
endmodule
