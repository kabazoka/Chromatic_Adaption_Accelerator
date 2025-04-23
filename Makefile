# Makefile for Chromatic Adaptation Accelerator testbenches
# For use with Icarus Verilog and oss-cad-suite on Mac M3

# Compiler settings
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TESTBENCH_DIR = testbench

# Source files
I2C_SRC = $(RTL_DIR)/i2c/i2c_als_interface.v
CCT_XYZ_SRC = $(RTL_DIR)/cct_xyz/cct_to_xyz_converter.v
BRADFORD_SRC = $(RTL_DIR)/chromatic_adapt/bradford_chromatic_adapt.v
IMAGE_PROC_SRC = $(RTL_DIR)/image_proc/image_processor.v
DISPLAY_SRC = $(RTL_DIR)/display_driver/display_driver.v
CONTROL_SRC = $(RTL_DIR)/control/control_unit.v
TOP_SRC = $(RTL_DIR)/chromatic_adaption_top.v

# Testbench files
I2C_TB = $(TESTBENCH_DIR)/i2c_als_interface_tb.v
CCT_XYZ_TB = $(TESTBENCH_DIR)/cct_to_xyz_converter_tb.v
BRADFORD_TB = $(TESTBENCH_DIR)/bradford_chromatic_adapt_tb.v
IMAGE_PROC_TB = $(TESTBENCH_DIR)/image_processor_tb.v
DISPLAY_TB = $(TESTBENCH_DIR)/display_driver_tb.v
CONTROL_TB = $(TESTBENCH_DIR)/control_unit_tb.v
TOP_TB = $(TESTBENCH_DIR)/chromatic_adaption_tb.v

# Output files
I2C_OUT = i2c_als_interface_tb.vvp
CCT_XYZ_OUT = cct_to_xyz_converter_tb.vvp
BRADFORD_OUT = bradford_chromatic_adapt_tb.vvp
IMAGE_PROC_OUT = image_processor_tb.vvp
DISPLAY_OUT = display_driver_tb.vvp
CONTROL_OUT = control_unit_tb.vvp
TOP_OUT = chromatic_adaption_tb.vvp

# VCD files for waveform viewing
I2C_VCD = i2c_als_interface_tb.vcd
CCT_XYZ_VCD = cct_to_xyz_converter_tb.vcd
BRADFORD_VCD = bradford_chromatic_adapt_tb.vcd
IMAGE_PROC_VCD = image_processor_tb.vcd
DISPLAY_VCD = display_driver_tb.vcd
CONTROL_VCD = control_unit_tb.vcd
TOP_VCD = chromatic_adaption_tb.vcd

# Compiler flags
IVERILOG_FLAGS = -g2012 -Wall

# Phony targets
.PHONY: all clean i2c cct_xyz bradford image_proc display control top
.PHONY: view_i2c view_cct_xyz view_bradford view_image_proc view_display view_control view_top

# Default target
all: i2c cct_xyz bradford image_proc display control top

# I2C testbench
i2c: $(I2C_OUT)
	$(VVP) $(I2C_OUT)

$(I2C_OUT): $(I2C_TB) $(I2C_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(I2C_OUT) $(I2C_TB) $(I2C_SRC)

# CCT to XYZ testbench
cct_xyz: $(CCT_XYZ_OUT)
	$(VVP) $(CCT_XYZ_OUT)

$(CCT_XYZ_OUT): $(CCT_XYZ_TB) $(CCT_XYZ_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(CCT_XYZ_OUT) $(CCT_XYZ_TB) $(CCT_XYZ_SRC)

# Bradford testbench
bradford: $(BRADFORD_OUT)
	$(VVP) $(BRADFORD_OUT)

$(BRADFORD_OUT): $(BRADFORD_TB) $(BRADFORD_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(BRADFORD_OUT) $(BRADFORD_TB) $(BRADFORD_SRC)

# Image processor testbench
image_proc: $(IMAGE_PROC_OUT)
	$(VVP) $(IMAGE_PROC_OUT)

$(IMAGE_PROC_OUT): $(IMAGE_PROC_TB) $(IMAGE_PROC_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(IMAGE_PROC_OUT) $(IMAGE_PROC_TB) $(IMAGE_PROC_SRC)

# Display driver testbench
display: $(DISPLAY_OUT)
	$(VVP) $(DISPLAY_OUT)

$(DISPLAY_OUT): $(DISPLAY_TB) $(DISPLAY_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(DISPLAY_OUT) $(DISPLAY_TB) $(DISPLAY_SRC)

# Control unit testbench
control: $(CONTROL_OUT)
	$(VVP) $(CONTROL_OUT)

$(CONTROL_OUT): $(CONTROL_TB) $(CONTROL_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(CONTROL_OUT) $(CONTROL_TB) $(CONTROL_SRC)

# Top level testbench
top: $(TOP_OUT)
	$(VVP) $(TOP_OUT)

$(TOP_OUT): $(TOP_TB) $(TOP_SRC) $(I2C_SRC) $(CCT_XYZ_SRC) $(BRADFORD_SRC) $(IMAGE_PROC_SRC) $(DISPLAY_SRC) $(CONTROL_SRC)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(TOP_OUT) $(TOP_TB) $(TOP_SRC) $(I2C_SRC) $(CCT_XYZ_SRC) $(BRADFORD_SRC) $(IMAGE_PROC_SRC) $(DISPLAY_SRC) $(CONTROL_SRC)

# View waveforms
view_i2c: $(I2C_VCD)
	$(GTKWAVE) $(I2C_VCD) &

view_cct_xyz: $(CCT_XYZ_VCD)
	$(GTKWAVE) $(CCT_XYZ_VCD) &

view_bradford: $(BRADFORD_VCD)
	$(GTKWAVE) $(BRADFORD_VCD) &

view_image_proc: $(IMAGE_PROC_VCD)
	$(GTKWAVE) $(IMAGE_PROC_VCD) &

view_display: $(DISPLAY_VCD)
	$(GTKWAVE) $(DISPLAY_VCD) &

view_control: $(CONTROL_VCD)
	$(GTKWAVE) $(CONTROL_VCD) &

view_top: $(TOP_VCD)
	$(GTKWAVE) $(TOP_VCD) &

# Clean up
clean:
	rm -f *.vvp *.vcd 