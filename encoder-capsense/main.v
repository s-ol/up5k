`include "../common/ws2812c.v"
`include "../common/util.v"
`include "../common/uart.v"

(* top *)
module top(
  input encoder_a,
  input encoder_b,
  input encoder_sw,
  inout encoder_cap,
  output serial_txd,
  input serial_rxd,
  output spi_cs,
  output led_rgb,
);
  wire reset = 0;
  wire clk_48;
  SB_HFOSC u_hfosc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(clk_48)
  );

  reg [31:0] counter;
  always @(posedge clk_48)
    if (reset)
      counter <= 0;
    else
      counter <= counter + 1;

  // generate a 1 MHz serial clock from the 48 MHz clock
  wire clk_1;
  divide_by_n #(.N(48)) div(clk_48, reset, clk_1);

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

  wire touched, clicked;

  quaddec_f4f #(.BITS(8), .STEP(2)) decoder(
    .clk(clk_48),
    .A(encoder_a),
    .B(encoder_b),

    /*
    .write(0),
    */
    .write_en(0),

    .count(count)
  );

  fade f(
    .count(count),
    .address(address),
    .brightness(bright)
  );

 /*
 assign bright = (address <= count[2:0])
                 ? 'hff
                 : 'h09;
 */

  rgb_sel s(
    .in(bright),
    .choice({touched, clicked}),
    .rgb({red, blue, green}) // swizzle colors
  );

  debounce click_sensor(
    .clk(counter[10]),
    .in(encoder_sw),
    .out(clicked)
  );

  wire touched, rawtouch;
  capsense #(.THRESH(115)) touch_sensor(
    .clk(counter[1]),
    .reset(counter[20]),
    .package_pin(encoder_cap),
    .count(value),
    .out(rawtouch)
  );

  debounce_biased #(.DELAY(2)) bnc(
    .clk(counter[20]),
    .in(rawtouch),
    .out(touched),
  );

  reg [7:0] uart_txd;
  reg uart_txd_strobe;
  wire uart_txd_ready;

  uart_tx txd(
    .mclk(clk_48),
    .reset(reset),
    .baud_x1(clk_1),
    .serial(serial_txd),
    .ready(uart_txd_ready),
    .data(uart_txd),
    .data_strobe(uart_txd_strobe)
  );

  wire [7:0] value;
  reg [1:0] byte_counter;

  always @(posedge clk_48) begin
    uart_txd_strobe <= 0;

    if (reset) begin
      // nothing
      byte_counter <= 0;
    end else
      if (uart_txd_ready && !uart_txd_strobe && counter[14:0] == 0) begin
        // ready to send a new byte
        uart_txd_strobe <= 1;

        if (byte_counter == 0)
          uart_txd <= "\r";
        else
          if (byte_counter == 1)
            uart_txd <= "\n";
          else if (byte_counter == 2)
            uart_txd <= value;
          else
            uart_txd <= touched ? 1 : 0;
          byte_counter <= byte_counter + 1;
        end
      end
endmodule

module debounce
  (
    input clk,
    input in,
    output reg out
  );
  reg [2:0] sw_delay;
  always @ (posedge clk) begin
    sw_delay <= {sw_delay[1:0], in};

    if (sw_delay[0] == sw_delay[1] == sw_delay[2])
      out <= sw_delay[0];
  end
endmodule

module debounce_biased
  #(
    parameter DELAY = 3,
  )
  (
    input clk,
    input in,
    output out,
  );
  reg [DELAY:0] sw_delay;

  assign out = |sw_delay;

  always @ (posedge clk)
    sw_delay <= {sw_delay[DELAY - 1:0], in};
endmodule

module capsense
  #(
    parameter THRESH = 140,
  )
  (
    input clk,
    input reset,
    inout package_pin,
    output reg [7:0] count,
    output reg out,
  );

  reg drive_pin = 0;
  wire sense_pin;

  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
  ) io_block_instance (
    .PACKAGE_PIN(package_pin),
    .OUTPUT_ENABLE(drive_pin),
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
          if (timing < 8'hff)
            timing <= timing + 1;
        end
      end
      STATE_DONE: begin
        count <= timing;
        out <= timing > THRESH;
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

// https://www.fpga4fun.com/QuadratureDecoder.html
module quaddec_f4f
  #(
    parameter BITS = 8,
    parameter STEP = 1,
  )
  (
    input clk,
    input A,
    input B,
    input [BITS-1:0] write,
    input write_en,
    output reg [BITS-1:0] count
  );

  reg [2:0] A_delay, B_delay;
  always @ (posedge clk) A_delay <= {A_delay[1:0], A};
  always @ (posedge clk) B_delay <= {B_delay[1:0], B};

  wire count_en = A_delay[1] ^ A_delay[2] ^ B_delay[1] ^ B_delay[2];
  wire count_dir = A_delay[1] ^ B_delay[2];

  always @ (posedge clk) begin
    if (write_en) begin
      count <= write;
    end else
    if (count_en) begin
      // if (count_dir)  count <= count + 1;
      // else            count <= count - 1;
      if (count_dir && count <= {BITS{1'b1}} - STEP) count <= count + STEP;
      else if (count >= STEP)                        count <= count - STEP;
    end
  end
endmodule
