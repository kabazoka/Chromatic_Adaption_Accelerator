@echo off
setlocal

echo ===================================================
echo  Bradford Chromatic Adaptation Testbench Runner
echo ===================================================

rem === Find ModelSim Installation (similar to run_ca_sim.bat) ===
set "FOUND_MODELSIM=0"
set "MODELSIM_PATH="
set "COMMON_PATHS=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem;C:\altera\13.0sp1\modelsim_ase\win32aloem;E:\altera\13.0sp1\modelsim_ase\win32aloem;C:\intelFPGA\20.1\modelsim_ase\win32aloem"

echo Searching for ModelSim in common paths...
for %%p in (%COMMON_PATHS%) do (
    if exist "%%p\vsim.exe" (
        echo Found ModelSim at: %%p
        set "MODELSIM_PATH=%%p"
        set "FOUND_MODELSIM=1"
        goto :modelsim_found_script
    )
)

:modelsim_found_script
if "%FOUND_MODELSIM%"=="0" (
    echo WARNING: Could not find ModelSim automatically in common paths.
    echo Will attempt to use 'vsim' from system PATH.
    echo If this fails, please add ModelSim to your PATH or edit this script.
)

rem Add ModelSim to PATH if found, otherwise assume it's already in PATH
if defined MODELSIM_PATH (
    set "PATH=%MODELSIM_PATH%;%PATH%"
    echo ModelSim path set to: %MODELSIM_PATH%
) else (
    echo Using ModelSim from system PATH.
)


rem === Simulation Steps ===
echo.
echo 1. Creating ModelSim work library (if it doesn't exist)...
if not exist work mkdir work
vlib work
if errorlevel 1 (
    echo ERROR: Failed to create work library.
    goto :script_error
)

echo.
echo 2. Mapping work library...
vmap work work
if errorlevel 1 (
    echo ERROR: Failed to map work library.
    goto :script_error
)

echo.
echo 3. Compiling Verilog files...
echo    Compiling CCT to XYZ converter: rtl/cct_xyz/cct_to_xyz_converter.v
vlog ../rtl/cct_xyz/cct_to_xyz_converter.v
if errorlevel 1 (
    echo ERROR: Failed to compile cct_to_xyz_converter.v
    goto :script_error
)

echo    Compiling Bradford Chromatic Adapt (UUT): rtl/chromatic_adapt/bradford_chromatic_adapt.v
vlog +define+SIM ../rtl/chromatic_adapt/bradford_chromatic_adapt.v
if errorlevel 1 (
    echo ERROR: Failed to compile bradford_chromatic_adapt.v
    goto :script_error
)

echo    Compiling Testbench: testbench/bradford_chromatic_adapt_tb.v
vlog ../testbench/bradford_chromatic_adapt_tb.v
if errorlevel 1 (
    echo ERROR: Failed to compile bradford_chromatic_adapt_tb.v
    goto :script_error
)

echo.
echo 4. Launching ModelSim simulation...
vsim -c -do "run -all; quit -f" work.bradford_chromatic_adapt_tb
if errorlevel 1 (
    echo ERROR: ModelSim simulation failed or did not complete.
    goto :script_error
)

echo.
echo ====================================================================
echo Testbench simulation completed successfully!
echo VCD file generated: bradford_chromatic_adapt_tb.vcd
echo Review console output for test results and error messages.
echo ====================================================================
goto :script_end

:script_error
echo.
echo ====================================================================
echo An error occurred. Please check the messages above.
echo ====================================================================
exit /b 1

:script_end
endlocal
echo.
pause 