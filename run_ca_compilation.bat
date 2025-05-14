@echo off
echo ====================================================================
echo Chromatic Adaptation Accelerator - Quartus Compilation Script
echo ====================================================================

echo.
echo Step 1: Creating/updating the Quartus project...
quartus_sh -t create_ca_project.tcl
if %ERRORLEVEL% NEQ 0 (
    echo Error in project creation.
    goto error
)

echo.
echo Step 2: Running Analysis and Synthesis...
quartus_map --read_settings_files=on --write_settings_files=off chromatic_adaptation -c chromatic_adaptation
if %ERRORLEVEL% NEQ 0 (
    echo Error in Analysis and Synthesis.
    goto error
)

echo.
echo Step 3: Running Fitter...
quartus_fit --read_settings_files=off --write_settings_files=off chromatic_adaptation -c chromatic_adaptation
if %ERRORLEVEL% NEQ 0 (
    echo Error in Fitter.
    goto error
)

echo.
echo Step 4: Running Assembler...
quartus_asm --read_settings_files=off --write_settings_files=off chromatic_adaptation -c chromatic_adaptation
if %ERRORLEVEL% NEQ 0 (
    echo Error in Assembler.
    goto error
)

echo.
echo Step 5: Running Timing Analysis...
quartus_sta chromatic_adaptation -c chromatic_adaptation
if %ERRORLEVEL% NEQ 0 (
    echo Error in Timing Analysis.
    goto error
)

echo.
echo Step 6: Generating simulation files...
quartus_eda --read_settings_files=off --write_settings_files=off chromatic_adaptation -c chromatic_adaptation --simulation --tool=modelsim --format=verilog
if %ERRORLEVEL% NEQ 0 (
    echo Error in EDA Netlist Writer.
    goto error
)

echo.
echo Compilation completed successfully!
echo.
echo To run the simulation, execute the following commands:
echo cd simulation/modelsim
echo vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc" image_processor_tb
echo.
echo Would you like to launch ModelSim now? (Y/N)
set /p launch_modelsim=

if /i "%launch_modelsim%"=="Y" (
    echo Launching ModelSim...
    cd simulation/modelsim
    vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc" image_processor_tb
) else (
    echo Exiting without launching ModelSim.
)

goto end

:error
echo.
echo ====================================================================
echo An error occurred during compilation. Please check the messages above.
echo ====================================================================
exit /b 1

:end
echo.
echo ====================================================================
echo Script completed.
echo ==================================================================== 