
module quaddec_dk
  #(
    parameter debounce_time = 65536
  )
  (
    input clk,
    input a,
    input b,

    output reg direction,
    output reg [7:0] count
  );

  reg [1:0] a_new, b_new;
  reg a_prev, b_prev;
  reg [18:0] debounce_cnt;

  always @ (posedge clk) begin
    // shift in a/b
    a_new <= { a_new[0], a };
    b_new <= { b_new[0], b };

    if ((a_new[0] ^ a_new[1]) || (b_new[0] ^ b_new[1])) begin
      debounce_cnt <= 0;
    end else if (debounce_cnt == debounce_time) begin
      a_prev <= a_new[1];
      b_prev <= b_new[1];
    end else begin
      debounce_cnt <= debounce_cnt + 1;
    end

    if (debounce_cnt == debounce_time
    && ((a_prev ^ a_new[1]) || (b_prev ^ b_new[1]))) begin
          direction <= b_prev ^ a_new[1];
          if (b_prev ^ a_new[1]) count <= count + 1;
          else count <= count - 1;
    end
  end
endmodule
