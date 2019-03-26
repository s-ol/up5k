// https://www.beyond-circuits.com/wordpress/wp-content/uploads/tutorials/tutorial11/debounce.v
/*
  wire encoder_a_db, encoder_b_db;
  wire encoder_a_rise, encoder_b_rise;
  wire encoder_a_fall, encoder_b_fall;

  debounce_bc #(.width(2),.bounce_limit(300000)) bnc(
    .clk(clk_48),
    .switch_in({ encoder_a, encoder_b }),
    .switch_out({ encoder_a_db, encoder_b_db }),
    .switch_rise({ encoder_a_rise, encoder_b_rise }),
    .switch_fall({ encoder_a_fall, encoder_b_fall })
  );
*/
module debounce_bc
  #(
    parameter width = 1,
    parameter bounce_limit = 1024
    )
  (
   input clk,
   input [width-1:0] switch_in,
   output reg [width-1:0] switch_out,
   output reg [width-1:0] switch_rise,
   output reg [width-1:0] switch_fall
   );

  genvar  i;
  generate
    for (i=0; i<width;i=i+1) begin
      reg [$clog2(bounce_limit)-1:0] bounce_count = 0;

      reg [1:0] switch_shift = 0;
      always @(posedge clk)
        switch_shift <= {switch_shift,switch_in[i]};

      always @(posedge clk)
        if (bounce_count == 0) begin
          switch_rise[i] <= switch_shift == 2'b01;
          switch_fall[i] <= switch_shift == 2'b10;
          switch_out[i] <= switch_shift[0];

          if (switch_shift[1] != switch_shift[0])
            bounce_count <= bounce_limit-1;
        end
        else begin
            switch_rise[i] <= 0;
            switch_fall[i] <= 0;
            bounce_count <= bounce_count-1;
          end
      end
  endgenerate
endmodule

// https://www.beyond-circuits.com/wordpress/tutorial/tutorial12/
module quaddec_bc (
  input clk,
  input a_rise,
  input b,
  output reg [7:0] count
);
  reg [7:0] enc_byte = 0;

  always @(posedge clk)
    if (a_rise)
      if (!b) count <= count - 1;
      else count <= count + 1;
endmodule
