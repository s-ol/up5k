![Upduino v2 RGB LEd](images/led.jpg)

Upduino v2 examples with apio/icestorm
====

Several demos showing how to use `apio` with the `icestorm` toolchain and the
Upduino (ice40 UltraPlus 5k) FPGA dev board.

| Demo | Description |
|------|-------------|
| `blink` | Flash the RED LED in a pulse-pulse, pulse-pulse pattern |
| `pulse` | Smoothly ramp the RGB LED through a color change pattern |
| `serial` | Print a repeating message on the serial port at 1 Mbs |
| `seral-echo` | Read from the serial port, echo it back at 3 Mbs |

Setup
====

install apio.
then install the toolchain etc:

    apio install system icestorm scons iverilog

Running
====

    cd pulse
    apio upload

Schematics and pinout
====

Schematics for the upduino: https://github.com/gtjennings1/UPDuino_v2_0

![Upduino v2 pinout by Matt Mets](images/pinout.jpg)

Note that the `upduino_v2.pcf` file disagrees with the serial port in
the pinout and schematic.  The pins were determined through experimentation
and seem to work (and the ones in the pinout do not).

UltraPlus 5K overview
===

![Block diagram](images/up5k.svg)

Overview: http://www.latticesemi.com/Products/FPGAandCPLD/iCE40UltraPlus

Datasheet: http://www.latticesemi.com/-/media/LatticeSemi/Documents/DataSheets/iCE/iCE40-UltraPlus-Family-Data-Sheet.ashx
