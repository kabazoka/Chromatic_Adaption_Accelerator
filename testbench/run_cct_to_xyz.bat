@echo off
setlocal

echo ===================================================
echo  CCT to XYZ Converter Testbench Runner
echo ===================================================

rem === Find ModelSim Installation ===
set "FOUND_MODELSIM=0"
set "MODELSIM_PATH="
set "COMMON_PATHS=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem;C:\altera\13.0sp1\modelsim_ase\win32aloem;E:\altera\13.0sp1\modelsim_ase\win32aloem;C:\intelFPGA\20.1\modelsim_ase\win32aloem"

echo Searching for ModelSim in common paths...
for %%p in (%COMMON_PATHS%) do (
    if exist "%%p\vsim.exe" (
        echo Found ModelSim at: %%p
        set "MODELSIM_PATH=%%p"
        set "FOUND_MODELSIM=1"
        goto :modelsim_found_cct_script
    )
)

:modelsim_found_cct_script
if "%FOUND_MODELSIM%"=="0" (
    echo WARNING: Could not find ModelSim automatically in common paths.
    echo Will attempt to use 'vsim' from system PATH.
    echo If this fails, please add ModelSim to your PATH or edit this script.
)

if defined MODELSIM_PATH (
    set "PATH=%MODELSIM_PATH%;%PATH%"
    echo ModelSim path set to: %MODELSIM_PATH%
) else (
    echo Using ModelSim from system PATH.
)

rem Adjust paths to be relative to the project root (one level up from this script)
set "PROJECT_ROOT=.."

echo.
echo 1. Creating ModelSim work library (if it doesn't exist)...
if not exist work mkdir work
vlib work
if errorlevel 1 (
    echo ERROR: Failed to create work library.
    goto :cct_script_error
)

echo.
echo 2. Mapping work library...
vmap work work
if errorlevel 1 (
    echo ERROR: Failed to map work library.
    goto :cct_script_error
)

echo.
echo 3. Compiling Verilog files...
echo    Compiling CCT to XYZ converter (UUT): %PROJECT_ROOT%\rtl\cct_xyz\cct_to_xyz_converter.v
vlog "%PROJECT_ROOT%\rtl\cct_xyz\cct_to_xyz_converter.v"
if errorlevel 1 (
    echo ERROR: Failed to compile cct_to_xyz_converter.v
    goto :cct_script_error
)

echo    Compiling Testbench: %PROJECT_ROOT%\testbench\cct_to_xyz_converter_tb.v
rem Add +define+SIM if your UUT or TB uses it for $display messages
rem If using 'string automatic' in tasks, may need SystemVerilog flags e.g. -sv
vlog "%PROJECT_ROOT%\testbench\cct_to_xyz_converter_tb.v"
if errorlevel 1 (
    echo ERROR: Failed to compile cct_to_xyz_converter_tb.v
    goto :cct_script_error
)

echo.
echo 4. Launching ModelSim simulation...
vsim -c -do "run -all; quit -f" work.cct_to_xyz_converter_tb
if errorlevel 1 (
    echo ERROR: ModelSim simulation failed or did not complete.
    goto :cct_script_error
)

echo.
echo ====================================================================
echo CCT to XYZ Testbench simulation completed successfully!
echo VCD file generated: cct_to_xyz_converter_tb.vcd (in work directory or script location)
echo Review console output for test results and error messages.
echo ====================================================================
goto :cct_script_end

:cct_script_error
echo.
echo ====================================================================
echo An error occurred. Please check the messages above.
echo ====================================================================
exit /b 1

:cct_script_end
endlocal
echo.
pause 