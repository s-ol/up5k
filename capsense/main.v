`include "../common/util.v"
`include "../common/uart.v"

(* top *)
module top(
  inout encoder_cap,
  output serial_txd,
  input serial_rxd,
  output spi_cs,
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

  wire touched;
  capsense #(.THRESH(138)) touch_sensor(
    .clk(counter[0]), // 4+ cycles @ 100pF
    .reset(~counter[20]),
    .package_pin(encoder_cap),
    .count(value),
    .out(touched)
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
            uart_txd <= 0;
          byte_counter <= byte_counter + 1;
        end
      end
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
          timing <= timing + 1;
        end
      end
      STATE_DONE: begin
        count <= timing;
        out <= timing > THRESH;
      end
    endcase
endmodule
