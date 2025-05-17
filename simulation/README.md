# Chromatic Adaptation Accelerator - Simulation

This directory contains simulation files for testing the Chromatic Adaptation Accelerator design.

## Color Checker Simulation

The color checker simulation allows you to visualize the effect of chromatic adaptation on a 4x4 grid of colors.

### Running the Simulation

1. Ensure you have ModelSim installed and in your PATH.
2. Make sure you have Python and the PIL (Pillow) library installed for image conversion:
   ```
   pip install pillow
   ```
3. Run the color checker simulation:
   ```
   ..\run_color_checker_sim.bat
   ```

### Output Files

After running the simulation, the following files will be created in the `simulation/modelsim` directory:

- `color_checker_input.ppm` - Original 4x4 color checker in PPM format
- `color_checker_output.ppm` - Chromatically adapted color checker in PPM format
- `color_checker_input.png` - Original color checker in PNG format
- `color_checker_output.png` - Chromatically adapted color checker in PNG format
- `color_checker_output.txt` - Detailed pixel information with original and adapted values

### Modifying the Simulation

You can modify the chromatic adaptation matrix in `color_checker_tb.v` to experiment with different color transformations:

1. Open `simulation/modelsim/color_checker_tb.v` in a text editor
2. Find the section initializing the compensation matrix (around line 90)
3. Modify the matrix values to achieve different color effects:
   - Increase red component for warmer colors
   - Increase blue component for cooler colors
   - Use an identity matrix (all 1.0 values on diagonal) for no adaptation

## Changing the Color Checker Pattern

To use a different set of colors in the color checker:

1. Modify the `color_checker` array initialization in `color_checker_tb.v`
2. Alternatively, modify the PPM creation in the batch file for a different input image

## Converting PPM to PNG Manually

If you want to convert PPM files to PNG manually, you can use the included Python script:

```
python ppm_to_png.py input.ppm output.png
``` 