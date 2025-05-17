@echo off
echo ====================================================================
echo Chromatic Adaptation Accelerator - Color Checker Simulation
echo ====================================================================

echo.
echo Setting up ModelSim work library...
if not exist "simulation\modelsim" mkdir simulation\modelsim
cd simulation\modelsim

echo.
echo 1. Creating ModelSim work library...
if exist work rmdir /s /q work
vlib work
if %ERRORLEVEL% NEQ 0 (
    echo Failed to create work library.
    goto error
)

echo.
echo 2. Mapping logical library to physical location...
vmap work work
if %ERRORLEVEL% NEQ 0 (
    echo Failed to map work library.
    goto error
)

echo.
echo 3. Creating 4x4 color checker input image...
echo P3 > color_checker_input.ppm
echo # 4x4 Color Checker >> color_checker_input.ppm
echo 4 4 >> color_checker_input.ppm
echo 255 >> color_checker_input.ppm
echo 255 0 0    0 255 0    0 0 255    255 255 0 >> color_checker_input.ppm
echo 0 255 255  255 0 255  128 128 128  255 255 255 >> color_checker_input.ppm
echo 165 42 42  0 128 0    0 0 128      255 165 0 >> color_checker_input.ppm
echo 255 192 203 128 0 128 0 128 128   210 180 140 >> color_checker_input.ppm

echo.
echo 4. Copying testbench file...
copy /Y ..\..\testbench\color_checker_tb.v .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to copy testbench file.
    goto error
)

echo.
echo 5. Compiling image_processor and testbench...
vlog -work work "../../rtl/image_proc/image_processor.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile image_processor.v
    goto error
)

vlog -work work "./color_checker_tb.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile color_checker_tb.v
    goto error
)

echo.
echo 6. Launching ModelSim simulation in console mode...
vsim -c -t 1ps -L work -voptargs="+acc" work.color_checker_tb -do "run -all; quit -f"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error launching ModelSim simulation.
    goto error
)

echo.
echo 7. Creating Python script for PPM to PNG conversion...
echo import sys > ppm_to_png.py
echo import os >> ppm_to_png.py
echo from PIL import Image >> ppm_to_png.py
echo. >> ppm_to_png.py
echo def ppm_to_png(ppm_file, png_file): >> ppm_to_png.py
echo     """Convert a PPM file to PNG""" >> ppm_to_png.py
echo     # Read PPM file >> ppm_to_png.py
echo     with open(ppm_file, 'r') as f: >> ppm_to_png.py
echo         lines = f.readlines() >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Extract header info >> ppm_to_png.py
echo     magic = lines[0].strip() >> ppm_to_png.py
echo     if magic != 'P3': >> ppm_to_png.py
echo         print(f"Error: {ppm_file} is not a P3 PPM file") >> ppm_to_png.py
echo         return False >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Skip comments >> ppm_to_png.py
echo     i = 1 >> ppm_to_png.py
echo     while lines[i].startswith('#'): >> ppm_to_png.py
echo         i += 1 >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Get dimensions >> ppm_to_png.py
echo     width, height = map(int, lines[i].split()) >> ppm_to_png.py
echo     i += 1 >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Get max value >> ppm_to_png.py
echo     max_val = int(lines[i].strip()) >> ppm_to_png.py
echo     i += 1 >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Create image >> ppm_to_png.py
echo     img = Image.new('RGB', (width, height)) >> ppm_to_png.py
echo     pixels = img.load() >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Read pixel data >> ppm_to_png.py
echo     data = [] >> ppm_to_png.py
echo     for j in range(i, len(lines)): >> ppm_to_png.py
echo         data.extend(lines[j].split()) >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Fill image with pixel data >> ppm_to_png.py
echo     data_idx = 0 >> ppm_to_png.py
echo     for y in range(height): >> ppm_to_png.py
echo         for x in range(width): >> ppm_to_png.py
echo             r = int(data[data_idx]) >> ppm_to_png.py
echo             g = int(data[data_idx + 1]) >> ppm_to_png.py
echo             b = int(data[data_idx + 2]) >> ppm_to_png.py
echo             pixels[x, y] = (r, g, b) >> ppm_to_png.py
echo             data_idx += 3 >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Save as PNG >> ppm_to_png.py
echo     img.save(png_file) >> ppm_to_png.py
echo     print(f"Converted {ppm_file} to {png_file}") >> ppm_to_png.py
echo     return True >> ppm_to_png.py
echo. >> ppm_to_png.py
echo if __name__ == '__main__': >> ppm_to_png.py
echo     # Check if input and output files were provided >> ppm_to_png.py
echo     if len(sys.argv) != 3: >> ppm_to_png.py
echo         print("Usage: python ppm_to_png.py input.ppm output.png") >> ppm_to_png.py
echo         sys.exit(1) >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     # Convert PPM to PNG >> ppm_to_png.py
echo     ppm_file = sys.argv[1] >> ppm_to_png.py
echo     png_file = sys.argv[2] >> ppm_to_png.py
echo     if not os.path.exists(ppm_file): >> ppm_to_png.py
echo         print(f"Error: {ppm_file} does not exist") >> ppm_to_png.py
echo         sys.exit(1) >> ppm_to_png.py
echo. >> ppm_to_png.py
echo     if ppm_to_png(ppm_file, png_file): >> ppm_to_png.py
echo         print("Conversion successful") >> ppm_to_png.py
echo     else: >> ppm_to_png.py
echo         print("Conversion failed") >> ppm_to_png.py
echo         sys.exit(1) >> ppm_to_png.py

echo.
echo 8. Converting PPM to PNG...
python ppm_to_png.py color_checker_input.ppm color_checker_input.png
python ppm_to_png.py color_checker_output.ppm color_checker_output.png

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error converting PPM to PNG. Make sure you have Python and PIL installed.
    echo You can install PIL with: pip install pillow
    goto end
)

echo.
echo ====================================================================
echo Simulation completed successfully!
echo ====================================================================
echo Output files in simulation\modelsim:
echo  - color_checker_input.ppm: Original 4x4 color checker in PPM format
echo  - color_checker_output.ppm: Chromatically adapted color checker in PPM format
echo  - color_checker_input.png: Original color checker in PNG format
echo  - color_checker_output.png: Chromatically adapted color checker in PNG format
echo  - color_checker_output.txt: Detailed pixel information
echo ====================================================================

goto end

:error
echo.
echo ====================================================================
echo An error occurred during simulation. Please check the messages above.
echo ====================================================================
cd ../../
exit /b 1

:end
cd ../../ 