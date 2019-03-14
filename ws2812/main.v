/** \file
 * Demo the pulsing LED on the upduino v2
 *
 * Note that the LED pins are inverted, so 0 is on
 */
`include "../common/ws2812c.v"

(* top *)
module top(
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
  reg [7:0] red;
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

  reg [31:0] counter;
  always @ (posedge clk_48)
    counter <= counter + 1;

  initial begin
    reset = 0;
    //green[7:4] = 0;
  end

  always @ (posedge new_address)
    red = 7 << (address >> 2);

  triwave#(.BITS(4)) grn(
    .clk(counter[18]),
    .out(green[3:0])
  );

  triwave#(.BITS(4)) blu(
    .clk(counter[19]),
    .out(blue[3:0])
  );

  always @ (posedge counter[19])
    reset <= counter[20];
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
