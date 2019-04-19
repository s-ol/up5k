`include "../common/ws2812c.v"

(* top *)
module top(
  input encoder_a,
  input encoder_b,
  input encoder_sw,
  inout encoder_cap,
  output led_rgb
);
  wire clk_48;
  SB_HFOSC u_hfosc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(clk_48)
  );

  reg [31:0] counter;
  always @ (posedge clk_48)
    counter <= counter + 1;

  wire [2:0] address;

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
      .reset(~counter[20]),

      .address(address),
      .red_in(red),
      .green_in(green),
      .blue_in(blue),

      .DO(led_rgb)
    );

  wire [7:0] bright;
  wire [7:0] count;

 assign bright = (address <= count[2:0])
                 ? 'hff
                 : 'h09;

  wire [1:0] choice;
  wire touched;


  rgb_sel s(
    .in(bright),
    .choice({1,touched}),
    .rgb({red, green, blue})
  );

  capsense senser(
    .clk(counter[5]), // ~3-4 cycles @ 100pF
    // .clk(counter[21]), // ~2-3 cycles @ 1uF
    .reset(counter[20]),
    .package_pin(encoder_cap),
    .count(count),
    .out(touched)
  );
endmodule

module capsense
  (
    input clk,
    input reset,
    inout package_pin,
    output reg [7:0] count,
    output reg out,
  );

  reg drive_pin;
  wire sense_pin;

  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
  ) io_block_instance (
    .PACKAGE_PIN(package_pin),
    .OUTPUT_ENABLE(reset),
    .D_OUT_0(0),
    .D_IN_0(sense_pin)
  );

  parameter STATE_START     = 2'd0; // start sample process
  parameter STATE_DRIVING   = 2'd1; // driving pin to zero
  parameter STATE_SAMPLING  = 2'd2; // waiting for pin to go high
  parameter STATE_DONE      = 2'd3; // waiting for restart

  reg [1:0] state = STATE_START;
  reg [7:0] timing;

  always @ (posedge clk)
    if (reset) state <= STATE_START;
    else case (state)
      STATE_START: begin
        drive_pin <= 1'b1;
        timing <= 0;
        state <= STATE_DRIVING;
      end
      STATE_DRIVING: begin
        timing <= timing + 1;
        if (timing > 8'h2) begin
          drive_pin <= 1'b0;
          timing <= 0;
          state <= STATE_SAMPLING;
        end
      end
      STATE_SAMPLING: begin
        if (sense_pin) begin
          state <= STATE_DONE;
        end else begin
          timing <= timing + 1;
        end
      end
      STATE_DONE: begin
        count <= timing;
        out <= timing > 2;
      end
    endcase
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
