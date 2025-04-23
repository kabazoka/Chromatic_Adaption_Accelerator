# Chromatic Adaptation Accelerator

A Verilog implementation of a chromatic adaptation system for the Terasic DE2-115 FPGA board. This system uses an Ambient Light Sensor (ALS) to measure the environmental light color temperature and adjusts image colors to make them appear as if viewed under standard D65 (6500K) lighting.

## System Architecture

The system consists of the following major components:

1. **I²C ALS Interface**: Communicates with an ambient light sensor to measure the current color temperature (CCT).
2. **CCT-to-XYZ Conversion**: Converts the CCT value to XYZ color space.
3. **Bradford Chromatic Adaptation**: Calculates the compensation matrix using the Bradford transform.
4. **Image Processor**: Converts sRGB to XYZ, applies compensation, and converts back to sRGB.
5. **Display Driver**: Interfaces with the display device.
6. **Control Unit**: Orchestrates the overall operation of the system.

## Directory Structure

```
.
├── rtl/                    # RTL source files
│   ├── i2c/                # I2C interface for ALS sensor
│   ├── cct_xyz/            # CCT to XYZ conversion
│   ├── chromatic_adapt/    # Bradford chromatic adaptation
│   ├── image_proc/         # Image processing
│   ├── display_driver/     # Display interface
│   └── control/            # Control unit
├── src/                    # Top-level files
├── testbench/              # Simulation testbench
└── docs/                   # Documentation
```

## Key Files

- `rtl/chromatic_adaption_top.v`: Main system module that connects all components
- `rtl/i2c/i2c_als_interface.v`: I²C interface to the ambient light sensor
- `rtl/cct_xyz/cct_to_xyz_converter.v`: Converts CCT to XYZ color space
- `rtl/chromatic_adapt/bradford_chromatic_adapt.v`: Bradford chromatic adaptation
- `rtl/image_proc/image_processor.v`: Image processing pipeline
- `rtl/display_driver/display_driver.v`: Display interface
- `rtl/control/control_unit.v`: System control
- `src/chromatic_adaption_de2_115.v`: Top-level wrapper for the DE2-115 board
- `testbench/chromatic_adaption_tb.v`: Simulation testbench

## Implementation Details

### Color Space Conversion

The system uses fixed-point arithmetic (Q16.16 format) for color space calculations, providing sufficient precision for color transformations while being efficient in hardware.

### Bradford Chromatic Adaptation

The Bradford transform is implemented as follows:

1. Convert the ambient white point (from the ALS) to cone responses by multiplying with the Bradford matrix.
2. Convert the reference white (D65) to cone responses using the same Bradford matrix.
3. Calculate the diagonal scaling matrix D by dividing the reference cone responses by the ambient cone responses.
4. Transform back to XYZ space using the inverse Bradford matrix.

The resulting compensation matrix is applied to image data in the XYZ color space.

### Fixed-Point Format

All color transformations use the Q16.16 fixed-point format:

- 16 bits for the integer part
- 16 bits for the fractional part

### I²C Interface

The I²C interface is designed to work with standard ALS sensors that provide CCT measurements. The implementation supports the I²C Fast mode (400 kHz).

## Hardware Requirements

- Terasic DE2-115 FPGA Development Board
- Ambient Light Sensor with I²C interface
- Display device (VGA or other suitable interface)

## Usage

1. Connect the ALS sensor to the I²C pins on the DE2-115 board.
2. Connect a display to the appropriate output interface.
3. Program the FPGA with the compiled bitstream.
4. The system will automatically read the ambient light CCT and apply compensation to the display output.

## Status Indication

The green LEDs on the DE2-115 board indicate the system status:

- LED[7]: ALS busy
- LED[6]: CCT valid
- LED[5]: XYZ valid
- LED[4]: Matrix valid
- LED[3]: Processing busy
- LED[2]: Display busy
- LED[1:0]: Current state

## Simulation

The testbench `chromatic_adaption_tb.v` can be used to simulate the system's operation. It provides test inputs and monitors the system's response.

## Future Improvements

- Support for more sophisticated CCT to xy conversion algorithms
- Hardware acceleration for gamma correction
- Support for different display interfaces
- Integration with an image memory controller for full-frame processing
