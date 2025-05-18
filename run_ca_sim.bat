@echo off
chcp 65001 >nul           rem  ← New: Change to UTF-8 code page
setlocal enabledelayedexpansion

rem ===================================================
echo ===================================================
echo  Chromatic Adaptation Accelerator - Simulation Menu
echo ===================================================

rem === ModelSim Directory ===
set "MODELSIM_PATH=E:\altera\13.0sp1\modelsim_ase\win32aloem"
rem System32 first, then ModelSim
set "PATH=%SystemRoot%\System32;%MODELSIM_PATH%;%PATH%"
echo ModelSim path set to: %MODELSIM_PATH%

rem === Check vlib.exe ===
if not exist "%MODELSIM_PATH%\vlib.exe" (
    echo ERROR: vlib.exe not found in "%MODELSIM_PATH%"
    goto ask_path
)

rem === Conda env check ===
if not defined CONDA_PREFIX (
    echo ERROR: Conda env not active.  ^(Please run 'conda activate als' first^)
    pause & exit /b 1
)
set "PYTHON_BIN=%CONDA_PREFIX%\python.exe"
if not exist "%PYTHON_BIN%" (
    echo ERROR: python.exe not found in "%CONDA_PREFIX%"
    pause & exit /b 1
)
echo Python found: %PYTHON_BIN%

rem === Pillow check ===
"%PYTHON_BIN%" -c "import PIL" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Pillow not installed.
    "%PYTHON_BIN%" -m pip install pillow || (
        echo Install Pillow failed.  Please run:
        echo   "%PYTHON_BIN%" -m pip install pillow
        pause
    )
) else (
    echo Pillow module OK.
)
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
vlog -work work "../../rtl/image_proc/image_processor.v"          || goto error
vlog -work work "../../rtl/cct_xyz/cct_to_xyz_converter.v"        || goto error
vlog -work work "../../rtl/chromatic_adapt/bradford_chromatic_adapt.v" || goto error
vlog -work work "./color_checker_tb.v"                            || goto error

echo.
echo 4. Launching ModelSim...
vsim -c -t 1ps -L work -voptargs="+acc" work.color_checker_tb ^
     -do "run -all; quit -f" -GCCT_VALUE=%cct_value% || goto error

echo.
echo 5. Converting PPM -> PNG…
copy /Y ..\..\python\ppm_to_png.py .                              >nul
"%PYTHON_BIN%" ppm_to_png.py color_checker_input.ppm  color_checker_input.png  || goto pyfail
"%PYTHON_BIN%" ppm_to_png.py color_checker_output.ppm color_checker_output.png || goto pyfail

echo.
echo Simulation completed successfully!
goto end_test

:pyfail
echo Error converting PPM to PNG – check Pillow installation.
goto end_test

:end_test
cd ../../
goto menu

rem ==================== Custom-Image Process ====================
:get_cct_custom_image
echo.
set /p cct_value="Enter CCT value [6500]: "
if "%cct_value%"=="" set cct_value=6500

rem …(Flow is the same as before, just replace all "python …" with "%PYTHON_BIN%" …)…

rem Example: PNG→PPM
"%PYTHON_BIN%" png_to_ppm.py %png_file% input_image.ppm || goto pyfail_img

rem Example: PPM→PNG
"%PYTHON_BIN%" ppm_to_png.py output_image.ppm output_image.png || goto pyfail_img

goto end_image_test

:pyfail_img
echo Error converting images – check Pillow installation.
goto end_image_test

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
