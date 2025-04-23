# Chromatic Adaptation Accelerator Testbenches

This directory contains testbenches for each module of the Chromatic Adaptation Accelerator. They are designed to work with Icarus Verilog and can be visualized using GTKWave.

## Requirements

- Icarus Verilog
- GTKWave (for waveform viewing)
- oss-cad-suite (recommended bundle for Mac M3)

## Testbenches Overview

1. **i2c_als_interface_tb.v** - Tests the I²C interface for the Ambient Light Sensor.
2. **cct_to_xyz_converter_tb.v** - Tests the conversion from CCT to XYZ color space.
3. **bradford_chromatic_adapt_tb.v** - Tests the Bradford chromatic adaptation calculations.
4. **image_processor_tb.v** - Tests the image processing pipeline (RGB->XYZ->RGB with compensation).
5. **display_driver_tb.v** - Tests the display driver module.
6. **control_unit_tb.v** - Tests the control unit that orchestrates the system.
7. **chromatic_adaption_tb.v** - Tests the complete system integration.

## Running the Testbenches

You can run the testbenches using the provided Makefile in the project root directory.

### For Individual Modules

To run a specific testbench and see its console output:

```bash
# For I2C interface
make i2c

# For CCT to XYZ converter
make cct_xyz

# For Bradford chromatic adaptation
make bradford

# For image processor
make image_proc

# For display driver
make display

# For control unit
make control

# For top-level system
make top
```

### Viewing Waveforms

Each testbench generates a .vcd file that can be viewed with GTKWave:

```bash
# For I2C interface
make view_i2c

# For CCT to XYZ converter
make view_cct_xyz

# For Bradford chromatic adaptation
make view_bradford

# For image processor
make view_image_proc

# For display driver
make view_display

# For control unit
make view_control

# For top-level system
make view_top
```

### Running All Testbenches

To run all testbenches:

```bash
make all
```

### Cleaning Up

To remove all generated files:

```bash
make clean
```

## Testbench Details

### I2C ALS Interface Testbench

Tests the I²C communication with the ALS sensor. The testbench simulates requesting CCT readings and verifies the output.

### CCT to XYZ Converter Testbench

Tests the conversion from color temperature (CCT) to XYZ color space. Tests various CCT values and boundary conditions.

### Bradford Chromatic Adaptation Testbench

Tests the Bradford chromatic adaptation algorithm. Provides different ambient white points and verifies the computed compensation matrices.

### Image Processor Testbench

Tests the image processing pipeline that converts RGB to XYZ, applies the compensation matrix, and converts back to RGB. Includes tests for identity transformation and different compensation matrices.

### Display Driver Testbench

Tests the display driver functionality, including input buffering and output generation based on display readiness.

### Control Unit Testbench

Tests the control unit that manages the overall system operation. Simulates the entire processing sequence from ALS reading to display update.

### Top-Level System Testbench

Tests the integration of all modules together, verifying end-to-end system functionality. 