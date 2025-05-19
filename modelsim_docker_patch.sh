#!/bin/bash
# This script patches ModelSim's vsim script in the Docker container to avoid Tk/Itcl issues

VSIM_PATH="/opt/intelFPGA_lite/13.0sp1/modelsim_ase/tcl/vsim/vsim"

# Create backup
cp "$VSIM_PATH" "${VSIM_PATH}.original"

# Replace "package require Itcl" with a version that won't fail
sed -i 's/package require Itcl/catch {package require Itcl}/g' "$VSIM_PATH"

# Replace other problematic package requires
sed -i 's/package require Tk/catch {package require Tk}/g' "$VSIM_PATH"
sed -i 's/package require Iwidgets/catch {package require Iwidgets}/g' "$VSIM_PATH"

echo "ModelSim patched successfully. You can now run the simulation." 