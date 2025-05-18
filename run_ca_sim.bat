@echo off
echo ====================================================================
echo Chromatic Adaptation Accelerator - Simulation Menu
echo ====================================================================

:menu
echo.
echo Please select a simulation to run:
echo.
echo 1. Color Checker Classic (6x4)
echo 2. Custom PNG Image (768x512)
echo 3. Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto run_color_checker
if "%choice%"=="2" goto run_custom_image
if "%choice%"=="3" goto end

echo Invalid choice, please try again.
goto menu

:run_color_checker
echo.
echo ====================================================================
echo Running Color Checker Classic Simulation
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
echo 3. Creating 6x4 Color Checker Classic input image...
echo P3 > color_checker_input.ppm
echo # 6x4 Color Checker Classic >> color_checker_input.ppm
echo 6 4 >> color_checker_input.ppm
echo 255 >> color_checker_input.ppm
echo 115 82 68    194 150 130    98 122 157     87 108 67     133 128 177    103 189 170 >> color_checker_input.ppm
echo 214 126 44   80 91 166      193 90 99      94 60 108     157 188 64     224 163 46 >> color_checker_input.ppm
echo 56 61 150    70 148 73      175 54 60      231 199 31    187 86 149     8 133 161 >> color_checker_input.ppm
echo 243 243 242  200 200 200    160 160 160    122 122 121   85 85 85       52 52 52 >> color_checker_input.ppm

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
echo 7. Copying PPM to PNG conversion script...
copy /Y ..\..\python\ppm_to_png.py .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to copy PPM to PNG conversion script.
    goto error
)

echo.
echo 8. Converting PPM to PNG...
python ppm_to_png.py color_checker_input.ppm color_checker_input.png
python ppm_to_png.py color_checker_output.ppm color_checker_output.png

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error converting PPM to PNG. Make sure you have Python and PIL installed.
    echo You can install PIL with: pip install pillow
    goto end_test
)

echo.
echo ====================================================================
echo Color Checker Simulation completed successfully!
echo ====================================================================
echo Output files in simulation\modelsim:
echo  - color_checker_input.ppm: Original 6x4 Color Checker Classic in PPM format
echo  - color_checker_output.ppm: Chromatically adapted Color Checker Classic in PPM format
echo  - color_checker_input.png: Original Color Checker Classic in PNG format
echo  - color_checker_output.png: Chromatically adapted Color Checker Classic in PNG format
echo  - color_checker_output.txt: Detailed patch information
echo ====================================================================

:end_test
cd ../../
goto menu

:run_custom_image
echo.
echo ====================================================================
echo Running Custom PNG Image Simulation
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
echo 3. Copy PNG to PPM converter script...
copy /Y ..\..\python\png_to_ppm.py .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to copy PNG to PPM converter.
    goto error
)

echo.
echo 4. Select PNG image to process (768x512)...
echo Please place your PNG image in the simulation\modelsim directory.
set /p png_file="Enter PNG filename (e.g., image.png): "

if not exist "%png_file%" (
    echo Error: File '%png_file%' not found.
    cd ../../
    goto menu
)

echo.
echo 5. Converting PNG to PPM format...
python png_to_ppm.py %png_file% input_image.ppm

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error converting PNG to PPM. Make sure you have Python and PIL installed.
    echo You can install PIL with: pip install pillow
    goto end_image_test
)

echo.
echo 6. Copying testbench file...
copy /Y ..\..\testbench\image_tb.v .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to copy testbench file.
    goto error
)

echo.
echo 7. Compiling image_processor and testbench...
vlog -work work "../../rtl/image_proc/image_processor.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile image_processor.v
    goto error
)

vlog -work work "./image_tb.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile image_tb.v
    goto error
)

echo.
echo 8. Launching ModelSim simulation in console mode...
echo This may take some time for a 768x512 image...
vsim -c -t 1ps -L work -voptargs="+acc" work.image_tb -do "run -all; quit -f"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error launching ModelSim simulation.
    goto error
)

echo.
echo 9. Copying PPM to PNG conversion script...
copy /Y ..\..\python\ppm_to_png.py .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to copy PPM to PNG conversion script.
    goto error
)

echo.
echo 10. Converting output PPM to PNG...
python ppm_to_png.py output_image.ppm output_image.png

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error converting PPM to PNG. Make sure you have Python and PIL installed.
    echo You can install PIL with: pip install pillow
    goto end_image_test
)

echo.
echo ====================================================================
echo Custom Image Simulation completed successfully!
echo ====================================================================
echo Output files in simulation\modelsim:
echo  - input_image.ppm: Original image in PPM format
echo  - output_image.ppm: Chromatically adapted image in PPM format
echo  - output_image.png: Chromatically adapted image in PNG format
echo ====================================================================

:end_image_test
cd ../../
goto menu

:error
echo.
echo ====================================================================
echo An error occurred during simulation. Please check the messages above.
echo ====================================================================
cd ../../
exit /b 1

:end
echo.
echo ====================================================================
echo Exiting simulation menu. Goodbye!
echo ==================================================================== 