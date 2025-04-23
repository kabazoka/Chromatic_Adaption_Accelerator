module chromatic_adaption_top (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // I2C interface for ALS sensor
    inout wire i2c_sda,
    inout wire i2c_scl,
    
    // Image input interface (placeholder - adapt based on actual data source)
    input wire [23:0] input_rgb_data,
    input wire input_valid,
    output wire input_ready,
    
    // Display output interface (placeholder - adapt based on actual display)
    output wire [23:0] output_rgb_data,
    output wire output_valid,
    input wire output_ready,
    
    // Debug/control
    input wire [3:0] sw,        // Switches for control
    output wire [7:0] led       // LEDs for status indication
);

    // Parameters
    parameter REF_CCT = 6500;   // Reference Color Temperature (D65) in Kelvin
    
    // Internal signals
    wire [15:0] ambient_cct;    // CCT value from ALS (e.g., 3000K-8000K)
    wire cct_valid;             // CCT reading is valid
    
    wire [31:0] ambient_xyz [2:0];  // Ambient white point in XYZ
    wire xyz_valid;                 // XYZ conversion valid
    
    wire [31:0] comp_matrix [8:0];  // 3x3 compensation matrix
    wire matrix_valid;              // Matrix calculation complete
    
    wire [23:0] processed_rgb_data; // RGB data after processing
    wire proc_valid;                // Processed data valid
    
    // Status signals
    wire als_busy;
    wire processing_busy;
    wire display_busy;

    // I2C ALS sensor interface module
    i2c_als_interface i2c_als_inst (
        .clk(clk),
        .rst_n(rst_n),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .read_req(control_als_read),
        .cct_out(ambient_cct),
        .cct_valid(cct_valid),
        .busy(als_busy)
    );
    
    // CCT to XYZ conversion module
    cct_to_xyz_converter cct_xyz_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cct_in(ambient_cct),
        .cct_valid(cct_valid),
        .xyz_out({ambient_xyz[0], ambient_xyz[1], ambient_xyz[2]}),
        .xyz_valid(xyz_valid)
    );
    
    // Chromatic adaptation module (Bradford transform)
    bradford_chromatic_adapt bradford_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ambient_xyz({ambient_xyz[0], ambient_xyz[1], ambient_xyz[2]}),
        .xyz_valid(xyz_valid),
        .ref_cct(REF_CCT),
        .comp_matrix(comp_matrix),
        .matrix_valid(matrix_valid)
    );
    
    // Image processing module
    image_processor img_proc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_rgb(input_rgb_data),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .comp_matrix(comp_matrix),
        .matrix_valid(matrix_valid),
        .output_rgb(processed_rgb_data),
        .output_valid(proc_valid),
        .busy(processing_busy)
    );
    
    // Display driver module
    display_driver display_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_rgb(processed_rgb_data),
        .input_valid(proc_valid),
        .output_rgb(output_rgb_data),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .busy(display_busy)
    );
    
    // Control unit
    wire control_als_read;
    
    control_unit control_inst (
        .clk(clk),
        .rst_n(rst_n),
        .als_busy(als_busy),
        .processing_busy(processing_busy),
        .display_busy(display_busy),
        .cct_valid(cct_valid),
        .xyz_valid(xyz_valid),
        .matrix_valid(matrix_valid),
        .sw(sw),
        .als_read_req(control_als_read),
        .leds(led)
    );

endmodule 