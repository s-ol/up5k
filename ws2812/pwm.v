module pwm_dim
  #(
    parameter WIDTH = 8,
    parameter ON = 1,
    parameter CYCLE = 8
  )
  (
    input clk,
    input [WIDTH-1:0] in,
    output [WIDTH-1:0] out,
  );

  reg [$clog2(CYCLE)-1:0] count;

  always @ (posedge clk) begin
    if (count >= CYCLE) count <= 0;
    else count <= count + 1;
  end

  assign out = (ON > count) ? in : 0;
endmodule
