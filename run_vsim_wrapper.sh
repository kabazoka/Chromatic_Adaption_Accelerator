#!/bin/bash
# ModelSim wrapper script to fix common issues

# Unset DISPLAY to prevent X11 connection attempts
unset DISPLAY

# More aggressively disable Tk
export VSIM_OPTS="-c -notcltk -notclpkg"
export MTI_GUI=0
export MTI_FORCENGUI=1
export MTI_TK=0
export MTI_TCL=0
export MTI_NOGUI=1
export MTI_STAYONTOP=0
export MTI_NOWARN_NONPRIVATE=1
export MTI_INSTALL=/opt/intelFPGA_lite/13.0sp1/modelsim_ase/

# Pass through all arguments to vsim, forcibly adding -c mode
/opt/intelFPGA_lite/13.0sp1/modelsim_ase/bin/vsim -c -notclpkg -notk -notcltk "$@" 