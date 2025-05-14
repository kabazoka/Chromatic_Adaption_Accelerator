@echo off
echo ====================================================================
echo Chromatic Adaptation Accelerator - ModelSim Simulation Script
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
echo 3. Compiling just the image_processor module...
vlog -work work "../../rtl/image_proc/image_processor.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile image_processor.v
    goto error
)

echo.
echo 4. Compiling just the image_processor testbench...
vlog -work work "../../testbench/image_processor_tb.v"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile image_processor_tb.v
    goto error
)

echo.
echo 5. Launching ModelSim simulation...
echo Current directory: %CD%
echo.
echo Running command: vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cycloneive_ver -L work -voptargs="+acc" work.image_processor_tb

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cycloneive_ver -L work -voptargs="+acc" work.image_processor_tb -do "add wave -position insertpoint sim:/image_processor_tb/*; run -all"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error launching ModelSim simulation.
    goto error
)

goto end

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
echo Simulation completed.
echo ====================================================================
cd ../../ 