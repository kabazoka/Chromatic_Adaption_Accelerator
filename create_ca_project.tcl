# --------------------------------------------------------------------
#  create_ca_project.tcl
#  Quartus‑II command‑line script
#  Creates/updates a project for the Chromatic Adaptation Accelerator
# --------------------------------------------------------------------

# ---------- project / revision names --------------------------------
set proj_name      "chromatic_adaptation"
set rev_name       "chromatic_adaptation"   ;# keep same as project
set top_entity     "chromatic_adaption_de2_115"   ;# <‑‑ edit if needed
# --------------------------------------------------------------------

# ---------- utility: recursive file collector -----------------------
proc recursive_file_list {path pattern} {
    set files {}
    foreach item [glob -directory $path -nocomplain *] {
        if {[file isdirectory $item]} {
            set files [concat $files [recursive_file_list $item $pattern]]
        } elseif {[string match $pattern $item]} {
            lappend files $item
        }
    }
    return $files
}

# ---------- create (or overwrite) the project -----------------------
project_new -overwrite $proj_name -revision $rev_name
project_open $proj_name -revision $rev_name

# ---------- device & family -----------------------------------------
set_global_assignment -name FAMILY  "Cyclone IV E"
set_global_assignment -name DEVICE  EP4CE115F29C7

# ---------- top‑level entity ----------------------------------------
set_global_assignment -name TOP_LEVEL_ENTITY $top_entity

# ---------- Verilog language version (optional) ---------------------
set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

# ---------- add RTL sources -----------------------------------------
foreach f [recursive_file_list "rtl" "*.v"] {
    puts "Adding RTL file  $f"
    set_global_assignment -name VERILOG_FILE $f
}
foreach f [recursive_file_list "src" "*.v"] {
    puts "Adding RTL file  $f"
    set_global_assignment -name VERILOG_FILE $f
}

# ---------- add testbench (simulation‑only) -------------------------
if {[file exists "testbench"]} {
    catch {create_fileset testbench}   ;# ignore error if it exists
    foreach f [recursive_file_list "testbench" "*.v"] {
        puts "Adding TB  file  $f"
        set_global_assignment -name VERILOG_FILE $f -section_id testbench
    }
}

# ---------- misc compile options you may want -----------------------
# Example: create an RBF for configuration flashes
# set_global_assignment -name GENERATE_RBF_FILE ON

# Specify EDA simulation tool settings
set_global_assignment -name EDA_SIMULATION_TOOL "ModelSim-Altera (Verilog)"
set_global_assignment -name EDA_TIME_SCALE "1 ps" -section_id eda_simulation
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT "VERILOG HDL" -section_id eda_simulation
set_global_assignment -name EDA_TEST_BENCH_ENABLE_STATUS TEST_BENCH_MODE -section_id eda_simulation
set_global_assignment -name EDA_TEST_BENCH_NAME image_processor_tb -section_id eda_simulation
set_global_assignment -name EDA_DESIGN_INSTANCE_NAME NA -section_id image_processor_tb
set_global_assignment -name EDA_TEST_BENCH_MODULE_NAME image_processor_tb -section_id image_processor_tb
set_global_assignment -name EDA_TEST_BENCH_FILE testbench/image_processor_tb.v -section_id image_processor_tb

# ---------- save & quit ---------------------------------------------
project_close
puts "Project $proj_name has been created/updated successfully."
exit
