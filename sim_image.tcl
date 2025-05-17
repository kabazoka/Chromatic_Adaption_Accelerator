# ModelSim TCL script for chromatic adaptation image simulation 
vlib work 
vlog -sv +define+SIM_AMBIENT_CCT=6500 rtl/i2c/i2c_als_interface.v rtl/cct_xyz/cct_to_xyz_converter.v rtl/chromatic_adapt/bradford_chromatic_adapt.v rtl/image_proc/image_processor.v rtl/display_driver/display_driver.v rtl/control/control_unit.v rtl/chromatic_adaption_top.v testbench/fixed_image_tb.v 
vsim -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L cycloneive_ver -L work -voptargs=+acc work.fixed_image_tb 
add wave -r * 
run 750ms 
quit -f 
