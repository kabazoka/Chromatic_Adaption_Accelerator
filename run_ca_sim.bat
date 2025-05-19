@echo off
chcp 65001 >nul           rem  ← New: Change to UTF-8 code page
setlocal enabledelayedexpansion

rem ===================================================
echo ===================================================
echo  Chromatic Adaptation Accelerator - Simulation Menu
echo ===================================================

rem === Find ModelSim Installation ===
set "FOUND_MODELSIM=0"
set "COMMON_PATHS=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem;C:\altera\13.0sp1\modelsim_ase\win32aloem;E:\altera\13.0sp1\modelsim_ase\win32aloem;C:\intelFPGA\20.1\modelsim_ase\win32aloem"

for %%p in (%COMMON_PATHS%) do (
    if exist "%%p\vlib.exe" (
        set "MODELSIM_PATH=%%p"
        set "FOUND_MODELSIM=1"
        goto :modelsim_found
    )
)

:modelsim_found
if "%FOUND_MODELSIM%"=="0" (
    echo ERROR: Could not find ModelSim installation automatically.
    goto ask_path
)

rem System32 first, then ModelSim
set "PATH=%SystemRoot%\System32;%MODELSIM_PATH%;%PATH%"
echo ModelSim path set to: %MODELSIM_PATH%

rem === Python Environment Setup ===
set "VENV_DIR=venv"
set "PYTHON_BIN=python"

rem Check if Python is installed
where python >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Please install Python 3.x from https://www.python.org/downloads/
    pause & exit /b 1
)

rem Get Python version
for /f "tokens=2" %%I in ('python --version 2^>^&1') do set PYTHON_VERSION=%%I
echo Found Python version: %PYTHON_VERSION%

rem Create venv if it doesn't exist
if not exist "%VENV_DIR%" (
    echo Creating Python virtual environment...
    python -m venv "%VENV_DIR%" 2>nul
    if errorlevel 1 (
        echo Trying alternative venv creation method...
        python -m virtualenv "%VENV_DIR%" 2>nul
        if errorlevel 1 (
            echo Failed to create virtual environment. Installing required packages globally...
            python -m pip install --user pillow
            set "PYTHON_BIN=python"
            goto :python_setup_complete
        )
    )
)

rem Activate venv and install requirements
echo Setting up Python environment...
if exist "%VENV_DIR%\Scripts\activate.bat" (
    call "%VENV_DIR%\Scripts\activate.bat"
    set "PYTHON_BIN=%~dp0%VENV_DIR%\Scripts\python.exe"
) else (
    echo Virtual environment activation failed. Using system Python...
    set "PYTHON_BIN=python"
)

:python_setup_complete
rem Install required packages
echo Installing required Python packages...
"%PYTHON_BIN%" -m pip install --upgrade pip
"%PYTHON_BIN%" -m pip install pillow

echo Python environment setup complete.
echo.

:menu
echo.
echo Please select a simulation to run:
echo 1. Color Checker Classic (6x4)
echo 2. Custom PNG Image (768x512)
echo 3. Exit
echo.
set /p choice="Enter your choice (1-3): "
if "%choice%"=="1" goto get_cct_color_checker
if "%choice%"=="2" goto get_cct_custom_image
if "%choice%"=="3" goto end
echo Invalid choice, please try again.
goto menu

rem ==================== Color-Checker Process ====================
:get_cct_color_checker
echo.
set /p cct_value="Enter CCT value [6500]: "
if "%cct_value%"=="" set cct_value=6500

echo.
echo ====================================================================
echo Running Color Checker Classic Simulation with CCT=%cct_value%K
echo ====================================================================

if not exist "simulation\modelsim" mkdir simulation\modelsim
cd simulation\modelsim

echo.
echo 1. Creating ModelSim work library...
if exist work rmdir /s /q work
vlib work || goto error
vmap work work || goto error

echo.
echo 2. Creating 6x4 Color Checker Classic input image...
rem (omitted) -- Original echo PPM generation block remains unchanged --

echo.
echo 3. Compiling RTL & testbench...
rem Copy testbench file first
echo Copying testbench file...
copy /Y ..\..\testbench\color_checker_tb.v . || (
    echo ERROR: Failed to copy color_checker_tb.v
    goto error
)

vlog -work work "../../rtl/image_proc/image_processor.v"          || goto error
vlog -work work "../../rtl/cct_xyz/cct_to_xyz_converter.v"        || goto error
vlog -work work "../../rtl/chromatic_adapt/bradford_chromatic_adapt.v" || goto error
vlog -work work "./color_checker_tb.v"                            || goto error

echo.
echo 4. Launching ModelSim...
vsim -c -notclpkg -t 1ps -L work -voptargs="+acc" work.color_checker_tb ^
     -do "run -all; quit -f" -GCCT_VALUE=%cct_value%
if not exist "color_checker_output.ppm" (
    echo ERROR: Simulation did not generate output file
    goto error
)

echo.
echo 5. Converting PPM -> PNG…
set "PYTHON_SCRIPTS_DIR=..\..\python"

rem Check if Python script exists
if not exist "%PYTHON_SCRIPTS_DIR%\ppm_to_png.py" (
    echo ERROR: ppm_to_png.py not found in %PYTHON_SCRIPTS_DIR%
    goto error
)

rem Check if input PPM exists
if not exist "color_checker_input.ppm" (
    echo ERROR: color_checker_input.ppm not found
    goto error
)

rem Check if output PPM exists
if not exist "color_checker_output.ppm" (
    echo ERROR: color_checker_output.ppm not found
    goto error
)

rem Copy and run conversion script
copy /Y "%PYTHON_SCRIPTS_DIR%\ppm_to_png.py" . >nul
if errorlevel 1 (
    echo ERROR: Failed to copy ppm_to_png.py
    goto error
)

echo Converting input PPM to PNG...
"%PYTHON_BIN%" ppm_to_png.py color_checker_input.ppm color_checker_input.png
if errorlevel 1 (
    echo ERROR: Failed to convert input PPM to PNG
    echo Current directory: %CD%
    echo Python script: %PYTHON_SCRIPTS_DIR%\ppm_to_png.py
    goto pyfail
)

echo Converting output PPM to PNG...
"%PYTHON_BIN%" ppm_to_png.py color_checker_output.ppm color_checker_output.png
if errorlevel 1 (
    echo ERROR: Failed to convert output PPM to PNG
    echo Current directory: %CD%
    echo Python script: %PYTHON_SCRIPTS_DIR%\ppm_to_png.py
    goto pyfail
)

rem Verify PNG files were created
if not exist "color_checker_input.png" (
    echo ERROR: Failed to create color_checker_input.png
    goto pyfail
)
if not exist "color_checker_output.png" (
    echo ERROR: Failed to create color_checker_output.png
    goto pyfail
)

echo PPM to PNG conversion completed successfully.
echo.
goto end

:pyfail
echo Error converting PPM to PNG. Details:
echo - Python executable: %PYTHON_BIN%
echo - Current directory: %CD%
echo - Python script location: %PYTHON_SCRIPTS_DIR%\ppm_to_png.py
echo - Pillow installation check:
"%PYTHON_BIN%" -c "import PIL; print('Pillow version:', PIL.__version__)" || echo Pillow not found
goto end

:get_cct_custom_image
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
rem 5. Converting PNG to PPM format...
"%PYTHON_BIN%" png_to_ppm.py "%png_file%" input_image.ppm  || goto pyfail


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
vlog -work work "../../rtl/image_proc/image_processor.v"          || goto error
vlog -work work "../../rtl/cct_xyz/cct_to_xyz_converter.v"        || goto error
vlog -work work "../../rtl/chromatic_adapt/bradford_chromatic_adapt.v" || goto error
vlog -work work "./image_tb.v"                            || goto error

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
rem 9. Copying PPM to PNG conversion script...
copy /Y ..\..\python\ppm_to_png.py .  || goto error

rem 10. Converting output PPM to PNG...
"%PYTHON_BIN%" ppm_to_png.py output_image.ppm output_image.png  || goto pyfail

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
goto end

rem ==================== Other sections remain unchanged ====================
:ask_path
echo.
echo Please enter correct ModelSim path (x to exit) :
set /p custom_path="> "
if /i "%custom_path%"=="x" exit /b 1
if exist "%custom_path%\vlib.exe" (
    set "MODELSIM_PATH=%custom_path%"
    set "PATH=%SystemRoot%\System32;%MODELSIM_PATH%;%PATH%"
    echo New ModelSim path: %MODELSIM_PATH%
) else (
    echo Still not found. Check installation.
    pause & exit /b 1
)
goto menu

:error
echo.
echo ====================================================================
echo An error occurred during simulation. Please check messages above.
echo ====================================================================
cd ../../
exit /b 1

:end
echo.
echo ====================================================================
echo Exiting simulation menu. Goodbye!
echo ===================================================================
