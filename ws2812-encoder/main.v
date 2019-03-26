/** \file
 * Demo the pulsing LED on the upduino v2
 *
 * Note that the LED pins are inverted, so 0 is on
 */
`include "../common/ws2812c.v"

(* top *)
module top(
  input encoder_a,
  input encoder_b,
  output encoder_c,
  output led_rgb
);
  wire clk_48;
  SB_HFOSC u_hfosc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(clk_48)
  );

  reg reset;

  wire [2:0] address;
  wire new_address;
  wire [2:0] selection;

  wire [7:0] red;
  wire [7:0] green;
  wire [7:0] blue;

  ws2812c
    #(
      .NUM_LEDS(8),
      .SYSTEM_CLOCK(48000000),
    ) driver
    (
      .clk(clk_48),
      .reset(reset),

      .address(address),
      .new_address(new_address),
      .red_in(red),
      .green_in(green),
      .blue_in(blue),

      .DO(led_rgb)
    );

  wire [7:0] count;
  assign encoder_c = 1;

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

  quaddec_f4f #(.BITS(8)) decoder(
    .clk(clk_48),
    .A(encoder_a_db),
    .B(encoder_b_db),
    .count(count)
  );

 /*
 quaddec_dk decoder(
   .clk(clk_48),
   .a(encoder_a),
   .b(encoder_b),
   .count(count)
 );
 */

  reg [31:0] counter;
  always @ (posedge clk_48)
    counter <= counter + 1;

  assign selection = count[2:0];

  assign red = address == selection ? 8'h06 : 0;
  assign green = address == selection ? 0 : 8'h06;
  assign blue = 0;

  always @ (posedge counter[19])
    reset <= counter[20];
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

// https://www.digikey.com/eewiki/pages/viewpage.action?pageId=62259228

// http://www.lothar-miller.de/s9y/categories/46-Encoder
/*
  wire [1:0] hin = {A, B};
  reg [1:0] smid, efin;

  always @ (posedge clk) begin
    smiddelay <= hin;
    efin <= smid;
  end

  reg i 

  always @ (posedge clk) begin
    i = 0 & efin[0];
    i = (i ^ e[1]) & e[1];
*/

// https://www.fpga4fun.com/QuadratureDecoder.html
module quaddec_f4f
  #(
    parameter BITS = 8
  )
  (
    input clk,
    input A,
    input B,
    output reg [BITS-1:0] count
  );

  reg [2:0] A_delay, B_delay;
  always @ (posedge clk) A_delay <= {A_delay[1:0], A};
  always @ (posedge clk) B_delay <= {B_delay[1:0], B};

  wire count_en = A_delay[1] ^ A_delay[2] ^ B_delay[1] ^ B_delay[2];
  wire count_dir = A_delay[1] ^ B_delay[2];

  always @ (posedge clk) begin
    if (count_en) begin
      if (count_dir)  count <= count + 1;
      else            count <= count - 1;
    end
  end
endmodule
