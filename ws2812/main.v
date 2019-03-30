/** \file
 * Demo the pulsing LED on the upduino v2
 *
 * Note that the LED pins are inverted, so 0 is on
 */
`include "../common/ws2812c.v"

(* top *)
module top
(
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

  wire [7:0] red, green, blue;

  wire [23:0] rgb;
  pwm_dim #(.WIDTH(24), .CYCLE(8)) dimmer(
    .clk(counter[15]),
    .in({red, green, blue}),
    .out(rgb)
  );

  ws2812c
    #(
      .NUM_LEDS(8),
      .SYSTEM_CLOCK(48_000_000),
    ) driver
    (
      .clk(clk_48),
      .reset(reset),

      .address(address),
      .new_address(new_address),
      .red_in  (rgb[ 7: 0]),
      .green_in(rgb[15: 8]),
      .blue_in (rgb[23:16]),

      .DO(led_rgb)
    );

  reg [31:0] counter;
  always @ (posedge clk_48)
    counter <= counter + 1;

  triwave grn(
    .clk(counter[18]),
    .out(green)
  );

  triwave blu(
    .clk(counter[19]),
    .out(blue)
  );

  triwave rd(
    .clk(counter[17]),
    .out(red)
  );

  always @ (posedge counter[14])
    reset <= counter[15];
endmodule

module triwave
  #(
    parameter BITS = 8,
  )
  (
    input clk,
    output reg [BITS-1:0] out
  );

  reg dir;

  function integer incdec;
    input integer value;
    input integer dir;
    begin
      if (dir <= 0) incdec = value - 1;
      else incdec = value + 1;
    end
  endfunction

  always @ (posedge clk) begin
    if (out == 0) dir = 1;
    if (out == (1 << BITS) - 1) dir = 0;

    if (dir)
      out <= out + 1;
    else
      out <= out - 1;
  end
endmodule
