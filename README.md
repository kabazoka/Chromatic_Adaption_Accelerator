# Chromatic Adaptation Accelerator

A Verilog implementation of a hardware chromatic adaptation system for the Terasic DE2-115 FPGA board. This system automatically adjusts display colors based on ambient lighting conditions to maintain color accuracy.

## System Overview

The Chromatic Adaptation Accelerator measures the color temperature of ambient light using an I²C ambient light sensor (ALS) and applies the Bradford chromatic adaptation transform to adjust colors, making them appear as if viewed under standard D65 (6500K) lighting.

## Features

- Real-time ambient light color temperature measurement
- Automatic white point adjustment using Bradford transform
- Fixed-point implementation for efficient hardware usage
- VGA display output with color correction
- Simulation and testing framework for all system components
- Full Quartus II FPGA implementation for DE2-115 board

## Architecture

The system is composed of six main modules:

1. **I²C ALS Interface**: Communicates with the ambient light sensor to obtain CCT readings
2. **CCT-to-XYZ Converter**: Transforms color temperature to XYZ color space coordinates
3. **Bradford Chromatic Adaptation**: Calculates adaptation matrices using the Bradford method
4. **Image Processor**: Applies color transformations to incoming RGB data
5. **Display Driver**: Manages display timing and color output
6. **Control Unit**: Orchestrates the overall system operation

## Directory Structure

```
.
├── rtl/                    # RTL Verilog source files
│   ├── chromatic_adaption_top.v  # Main system integration module
│   ├── i2c/                # I2C interface modules
│   ├── cct_xyz/            # CCT to XYZ conversion
│   ├── chromatic_adapt/    # Bradford transform implementation
│   ├── image_proc/         # Image processing pipeline
│   ├── display_driver/     # Display interface
│   └── control/            # System control logic
├── src/                    # FPGA-specific implementation
│   └── chromatic_adaption_de2_115.v  # DE2-115 top-level wrapper
├── testbench/              # Simulation testbenches
├── simulation/             # Simulation output directory
├── db/                     # Quartus database files
├── incremental_db/         # Quartus incremental compilation files
├── Makefile                # Make rules for simulation
└── *.bat, *.tcl            # Build scripts for Quartus
```

## Hardware Requirements

- Terasic DE2-115 FPGA Development Board (Altera Cyclone IV E)
- Ambient Light Sensor with I²C interface and CCT measurement
- VGA display or monitor

## Build Instructions

### FPGA Synthesis (Windows)

To compile the project for the DE2-115 FPGA:

```bash
# Run the automated compilation script
run_ca_compilation.bat
```

This script:
1. Creates/updates the Quartus project using create_ca_project.tcl
2. Runs Analysis & Synthesis
3. Performs Place & Route (Fitter)
4. Generates the programming file
5. Runs timing analysis
6. Creates simulation files

### Simulation

#### Using Makefile (Linux/Mac/WSL)

The project includes comprehensive testbenches for each module using Icarus Verilog:

```bash
# Run a specific testbench
make i2c           # I2C interface
make cct_xyz       # CCT to XYZ converter
make bradford      # Bradford adaptation
make image_proc    # Image processor
make display       # Display driver
make control       # Control unit
make top           # Top-level system

# View waveforms
make view_i2c      # and similarly for other modules

# Run all testbenches
make all

# Clean generated files
make clean
```

#### Using Batch Script (Windows)

For Windows users, simulation can also be run using the provided batch script:

```bash
# Run ModelSim simulation
run_ca_simulation.bat
```

This script automatically:
1. Sets up the ModelSim environment
2. Compiles all RTL and testbench files
3. Launches the ModelSim GUI with the specified testbench loaded
4. Configures waveforms for viewing

#### Color Checker Simulation (Windows)

To run the chromatic adaptation simulation:

```bash
# Run the chromatic adaptation simulation menu
run_ca_sim.bat
```

This script provides an interactive menu with the following options:
1. Color Checker Classic (6x4) - Simulates adaptation on standard color checker
2. Custom PNG Image (768x512) - Process your own PNG image
3. Exit

**Color Checker Classic Simulation:**
- Creates a 6x4 color checker input pattern
- Runs the simulation in console mode (no GUI)
- Generates output files in the `simulation/modelsim` directory:
  - `color_checker_input.ppm`: Original color pattern (PPM format)
  - `color_checker_output.ppm`: Chromatically adapted colors (PPM format)
  - `color_checker_input.png`: Original color pattern (PNG format)
  - `color_checker_output.png`: Chromatically adapted colors (PNG format)
  - `color_checker_output.txt`: Detailed patch information before and after adaptation

**Custom PNG Image Simulation:**
- Allows processing of user-provided 768x512 PNG images
- Converts the PNG to PPM for processing
- Generates output files in the `simulation/modelsim` directory:
  - `input_image.ppm`: Original image (PPM format)
  - `output_image.ppm`: Chromatically adapted image (PPM format)
  - `output_image.png`: Chromatically adapted image (PNG format)

The simulation applies a warm-tinting adaptation matrix that:
- Boosts red component (1.1×)
- Slightly boosts green component (1.05×)
- Reduces blue component (0.9×)

**Prerequisites**: 
- ModelSim must be installed and in your PATH
- Python with the Pillow library (`pip install pillow`) for PNG/PPM conversions

## Implementation Details

### Fixed-Point Representation

Color transformations use Q16.16 fixed-point format:
- 16 bits for integer part
- 16 bits for fractional part

### Bradford Chromatic Adaptation Algorithm

1. Convert source white point (from ALS) to cone responses using Bradford matrix
2. Convert destination white point (D65) to cone responses
3. Calculate scaling ratios between destination and source cone responses
4. Transform back to XYZ using inverse Bradford transform
5. Apply resulting matrix to input colors in XYZ space

### I²C Protocol

The ALS interface implements I²C Fast mode (400 kHz) to communicate with the ambient light sensor.

### System Status Indication

The green LEDs on the DE2-115 board show system status:
- LED[7]: ALS sensor communication status
- LED[6]: CCT reading validity
- LED[5]: XYZ conversion status
- LED[4]: Matrix calculation status
- LED[3]: Image processing status
- LED[2]: Display interface status
- LED[1:0]: System state

## Simulation and Testing

Each module has a dedicated testbench in the `testbench/` directory. See `testbench/README.md` for detailed information on running and interpreting test results.

## Performance Metrics

The design targets the Altera Cyclone IV E FPGA on the DE2-115 board:
- Operating frequency: 50 MHz
- Resource utilization varies by module (see .rpt files for details)
- Fixed-point precision allows accurate color transformations with efficient hardware usage

## Contact

For questions or contributions to this project, please open an issue or pull request on the repository.
