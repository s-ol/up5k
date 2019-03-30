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
  input encoder_sw,
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

  quaddec_f4f #(.BITS(8)) decoder(
    .clk(clk_48),
    .A(encoder_a),
    .B(encoder_b),
    .count(count)
  );

  reg [31:0] counter;
  always @ (posedge clk_48)
    counter <= counter + 1;

  assign selection = count[4:2];

  wire [7:0] bright;

  fade f(
    .count(count),
    .address(address),
    .brightness(bright)
  );

  reg [1:0] choice;

  rgb_sel s(
    .in(bright),
    .choice(choice),
    .rgb({red, green, blue})
  );

  reg [2:0] sw_delay;
  always @ (posedge counter[15]) begin
    sw_delay <= {sw_delay[1:0], encoder_sw};

    if (sw_delay[0] && sw_delay[1] && !sw_delay[2])
      choice <= choice + 1;
  end

  always @ (posedge counter[19])
    reset <= counter[20];
endmodule

// fade between 0 and 1
module fade
  (
    input [7:0] count,
    input [2:0] address,
    output reg [7:0] brightness
  );

  wire [7:0] thresh;

  assign thresh = {address, 5'h0};
  always @ * begin
    if (count < thresh) brightness <= 8'h0;
    else if (count < thresh + 'h3f) brightness <= count - thresh;
    else brightness <= 'h3f;
  end
endmodule

module rgb_sel
  (
    input [7:0] in,
    input [1:0] choice,
    output reg [23:0] rgb
  );

  always @ *
    case (choice)
      0 : rgb <= 0;
      1 : rgb <= { in, 8'h0, 8'h0 };
      2 : rgb <= { 8'h0, in, 8'h0 };
      3 : rgb <= { 8'h0, 8'h0, in };
    endcase
endmodule

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
      // if (count_dir)  count <= count + 1;
      // else            count <= count - 1;
      if (count_dir && count < {BITS{1'b1}}) count <= count + 1;
      else if (count > 0)                    count <= count - 1;
    end
  end
endmodule
