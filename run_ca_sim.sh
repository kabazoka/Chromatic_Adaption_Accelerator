#!/usr/bin/env bash
###############################################################################
# Chromatic Adaptation Accelerator – Simulation Menu
# Works inside the Quartus-13 container (no Conda, uses system Python3)
###############################################################################
set -euo pipefail
export LC_ALL=C.UTF-8

# Disable environment variables that might trigger GUI/Tk
unset DISPLAY
export MTI_NOWARN_NONPRIVATE=1

# Find ModelSim tools
VLIB=$(command -v vlib || echo "")
VLOG=$(command -v vlog || echo "")
VSIM=$(command -v vsim || echo "")
VMAP=$(command -v vmap || echo "")

# Check if tools exist
if [[ -z "$VLIB" ]]; then
    echo "Error: vlib not found in PATH"
    exit 1
fi
if [[ -z "$VLOG" ]]; then
    echo "Error: vlog not found in PATH"
    exit 1
fi
if [[ -z "$VSIM" ]]; then
    echo "Error: vsim not found in PATH"
    exit 1
fi
if [[ -z "$VMAP" ]]; then
    echo "Error: vmap not found in PATH"
    exit 1
fi

echo "Found ModelSim tools:"
echo "vlib: $VLIB"
echo "vlog: $VLOG"
echo "vsim: $VSIM"
echo "vmap: $VMAP"

###############################################################################
# 0) Python (and Pillow) detection
###############################################################################
if command -v python3 &>/dev/null; then
    PYTHON_BIN=$(command -v python3)
elif command -v python &>/dev/null; then         # Python 2 fallback (rare)
    PYTHON_BIN=$(command -v python)
else
    cat >&2 <<'EOF'
ERROR: Python not found inside the container.

Fix (as root inside the container):
    apt-get update && apt-get install -y python3 python3-pip
EOF
    exit 1
fi
echo "Python found: $PYTHON_BIN"

# ----------------------------------------------------------------------------
# Pillow detection  (wrapped in an 'if … ; then … else … fi' so 'set -e' is happy)
# ----------------------------------------------------------------------------
if "$PYTHON_BIN" - <<'PY'
import sys
try:
    import PIL          # noqa
    sys.exit(0)         # found
except ImportError:
    sys.exit(1)         # missing
PY
then
    echo "Python Pillow available."
else
    echo "Pillow missing – installing..."
    if command -v pip3 &>/dev/null; then
        pip3 install --user pillow
    else
        echo "pip3 missing -> installing system packages (needs root)"
        if command -v apt-get &>/dev/null; then
            apt-get update &&
            apt-get install -y python3-pip python3-setuptools
        elif command -v yum &>/dev/null; then
            yum install -y python3-pip
        else
            echo "No apt-get or yum; install Pillow manually."
            exit 1
        fi
        pip3 install --user pillow
    fi
fi

###############################################################################
# 1) ModelSim utilities present?
###############################################################################
if [[ -z "$VLIB" ]]; then
    cat >&2 <<'EOF'
ERROR: vlib not found in PATH.

Please ensure ModelSim executables are in your PATH.
You might need to:
  • Add the ModelSim bin directory to your PATH environment variable, or
  • Install ModelSim-ASE Lite and ensure its bin directory is added to PATH.
EOF
    exit 1
fi
if [[ -z "$VLOG" ]]; then
    cat >&2 <<'EOF'
ERROR: vlog not found in PATH. Please ensure ModelSim executables are in your PATH.
EOF
    exit 1
fi
if [[ -z "$VSIM" ]]; then
    cat >&2 <<'EOF'
ERROR: vsim not found in PATH. Please ensure ModelSim executables are in your PATH.
EOF
    exit 1
fi
if [[ -z "$VMAP" ]]; then
    cat >&2 <<'EOF'
ERROR: vmap not found in PATH. Please ensure ModelSim executables are in your PATH.
EOF
    exit 1
fi

###############################################################################
# 2) Helper functions
###############################################################################
make_lib () {
    echo "--> Re-creating ModelSim library"
    rm -rf work
    "$VLIB" work
    "$VMAP" work work
}

# Define Tcl commands to disable GUI - used within the vsim -do option
DISABLE_GUI_COMMANDS='
proc GUIInit_TK {} { return }
proc WaveRestoreZoom {} { return }
proc PrefMain {} { return }
proc Wave {} { return }
proc WaveW {} { return }
proc WindowC {} { return }
proc WinMain {} { return }
proc XWin {} { return }
'

run_color_checker () {
    read -rp "Enter CCT value [6500] : " cct
    cct=${cct:-6500}

    echo "=== Color-Checker Classic (CCT=${cct} K) ==="
    mkdir -p simulation/modelsim && cd simulation/modelsim
    
    make_lib

    echo "--> Compiling RTL & testbench"
    "$VLOG" -work work ../../rtl/image_proc/image_processor.v
    "$VLOG" -work work ../../rtl/cct_xyz/cct_to_xyz_converter.v
    "$VLOG" -work work ../../rtl/chromatic_adapt/bradford_chromatic_adapt.v
    "$VLOG" -work work ./color_checker_tb.v

    echo "--> Running ModelSim (console)"
    # Force strict console mode with GUI-disabling commands
    "$VSIM" -c -quiet -novopt -t 1ps -L work \
         work.color_checker_tb -do "${DISABLE_GUI_COMMANDS}; run -all; quit -f" \
         -GCCT_VALUE="$cct"

    echo "--> Converting PPM → PNG"
    cp -f ../../python/ppm_to_png.py .
    "$PYTHON_BIN" ppm_to_png.py color_checker_input.ppm  color_checker_input.png
    "$PYTHON_BIN" ppm_to_png.py color_checker_output.ppm color_checker_output.png

    echo "Output PNGs are in $(pwd)"
    cd ../../..
}

run_custom_png () {
    mkdir -p simulation/modelsim && cd simulation/modelsim
    
    make_lib

    cp -f ../../python/png_to_ppm.py .

    read -rp "PNG file (768×512) in $(pwd): " png
    [[ -f "$png" ]] || { echo "File not found."; cd -; return; }

    "$PYTHON_BIN" png_to_ppm.py "$png" input_image.ppm

    cp -f ../../testbench/image_tb.v .

    "$VLOG" -work work ../../rtl/image_proc/image_processor.v
    "$VLOG" -work work ../../rtl/cct_xyz/cct_to_xyz_converter.v
    "$VLOG" -work work ../../rtl/chromatic_adapt/bradford_chromatic_adapt.v
    "$VLOG" -work work ./image_tb.v

    # Force strict console mode with GUI-disabling commands
    "$VSIM" -c -notclpkg -quiet -novopt -t 1ps -L work \
         work.image_tb -do "${DISABLE_GUI_COMMANDS}; run -all; quit -f"

    cp -f ../../python/ppm_to_png.py .
    "$PYTHON_BIN" ppm_to_png.py output_image.ppm output_image.png

    echo "Custom image processed – result is output_image.png"
    cd ../../..
}

###############################################################################
# 3) Interactive menu
###############################################################################
while :; do
cat <<'BANNER'

===================================================
 Chromatic Adaptation Accelerator – Simulation Menu
===================================================
1) Color-Checker Classic (6×4)
2) Custom PNG Image (768×512)
3) Exit
BANNER
    read -rp "Choice [1-3]: " ans
    case $ans in
        1) run_color_checker ;;
        2) run_custom_png   ;;
        3) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
done