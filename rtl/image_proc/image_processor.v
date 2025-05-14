module image_processor (
    input wire clk,
    input wire rst_n,
    
    // Input RGB data
    input wire [23:0] input_rgb,        // RGB input (8 bits per channel)
    input wire input_valid,             // Input data valid
    output reg input_ready,             // Ready to accept input
    
    // Compensation matrix - changed from unpacked to packed format
    input wire [287:0] comp_matrix,     // 3x3 compensation matrix from Bradford (flattened)
    input wire matrix_valid,            // Matrix is valid
    
    // Output RGB data
    output reg [23:0] output_rgb,       // RGB output (8 bits per channel)
    output reg output_valid,            // Output data valid
    
    // Status
    output reg busy                     // Processing unit is busy
);

    // Fixed-point format settings (Q16.16)
    localparam INT_BITS = 16;
    localparam FRAC_BITS = 16;
    localparam Q_FORMAT = 32;  // Total bits
    
    // Fixed-point 1.0 in Q16.16 format
    localparam FP_ONE = 32'h00010000;
    
    // State machine definitions
    localparam IDLE = 3'd0;
    localparam RGB_TO_XYZ = 3'd1;
    localparam APPLY_COMP = 3'd2;
    localparam XYZ_TO_RGB = 3'd3;
    localparam OUTPUT = 3'd4;
    
    // sRGB to XYZ matrix (fixed-point Q16.16)
    parameter M_RGB_TO_XYZ_00 = 32'h00006587; // 0.4124
    parameter M_RGB_TO_XYZ_01 = 32'h00003430; // 0.2126
    parameter M_RGB_TO_XYZ_02 = 32'h00000F7C; // 0.0193
    parameter M_RGB_TO_XYZ_10 = 32'h00002151; // 0.3576
    parameter M_RGB_TO_XYZ_11 = 32'h00007258; // 0.7152
    parameter M_RGB_TO_XYZ_12 = 32'h00001257; // 0.1192
    parameter M_RGB_TO_XYZ_20 = 32'h00000332; // 0.1805
    parameter M_RGB_TO_XYZ_21 = 32'h00000977; // 0.0722
    parameter M_RGB_TO_XYZ_22 = 32'h0000E357; // 0.9505
    
    // XYZ to sRGB matrix (fixed-point Q16.16)
    parameter M_XYZ_TO_RGB_00 = 32'h00032085; // 3.2406
    parameter M_XYZ_TO_RGB_01 = 32'hFFFF0FCB; // -1.5372
    parameter M_XYZ_TO_RGB_02 = 32'hFFFFD80F; // -0.4986
    parameter M_XYZ_TO_RGB_10 = 32'hFFFF9B33; // -0.9689
    parameter M_XYZ_TO_RGB_11 = 32'h0001E5CE; // 1.8758
    parameter M_XYZ_TO_RGB_12 = 32'h00000C3C; // 0.0415
    parameter M_XYZ_TO_RGB_20 = 32'h00000830; // 0.0557
    parameter M_XYZ_TO_RGB_21 = 32'hFFFFAC0F; // -0.2040
    parameter M_XYZ_TO_RGB_22 = 32'h00010AF5; // 1.0570
    
    // Internal registers
    reg [2:0] state;
    reg [7:0] r_in, g_in, b_in;               // Input RGB components
    
    // Replace unpacked arrays with packed arrays
    reg [95:0] rgb_linear;                     // Linear RGB values (gamma removed)
    reg [95:0] xyz_values;                     // XYZ color space values
    reg [95:0] xyz_adapted;                    // Adapted XYZ values
    reg [95:0] rgb_linear_out;                 // Linear RGB after conversion back
    
    reg [7:0] r_out, g_out, b_out;            // Output RGB components
    
    // For unpacking the matrix
    wire [31:0] comp_mat_00, comp_mat_01, comp_mat_02;
    wire [31:0] comp_mat_10, comp_mat_11, comp_mat_12;
    wire [31:0] comp_mat_20, comp_mat_21, comp_mat_22;
    
    // Temporary working registers
    reg [31:0] temp_val;
    
    integer i; // Loop counter
    
    // Unpack the compensation matrix
    assign comp_mat_00 = comp_matrix[31:0];
    assign comp_mat_01 = comp_matrix[63:32];
    assign comp_mat_02 = comp_matrix[95:64];
    assign comp_mat_10 = comp_matrix[127:96];
    assign comp_mat_11 = comp_matrix[159:128];
    assign comp_mat_12 = comp_matrix[191:160];
    assign comp_mat_20 = comp_matrix[223:192];
    assign comp_mat_21 = comp_matrix[255:224];
    assign comp_mat_22 = comp_matrix[287:256];
    
    // Fixed-point arithmetic helper functions
    function [31:0] fp_multiply;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] result;
        begin
            result = a * b;
            fp_multiply = result >> FRAC_BITS;
        end
    endfunction
    
    // Gamma correction functions
    // sRGB gamma removal (approximate)
    function [31:0] gamma_remove;
        input [7:0] srgb_val;
        reg [31:0] linear;
        begin
            // Convert 8-bit value to normalized range [0,1] using fixed-point
            
            // Apply gamma removal
            // Simplified: if normalized < 0.04045 then normalized / 12.92
            // else ((normalized + 0.055) / 1.055)^2.4
            if (srgb_val < 11) // ~0.04045 * 255
                linear = (srgb_val << FRAC_BITS) / 255;
            else begin
                // Approximation using lookup and linear interpolation
                // would be implemented here in actual hardware
                // Simplified version: use squared value as approximation
                linear = ((srgb_val * srgb_val) << (FRAC_BITS - 8)) / 255;
            end
            
            gamma_remove = linear;
        end
    endfunction
    
    // Gamma application (approximate)
    function [7:0] gamma_apply;
        input [31:0] linear;
        reg [7:0] srgb_val;
        begin
            // Simplified gamma application using fixed-point
            // In real implementation would use lookup + interpolation
            
            // Quick approximation: sqrt of value * 255
            // Proper gamma would be:
            // if linear <= 0.0031308 then linear * 12.92
            // else 1.055 * linear^(1/2.4) - 0.055
            srgb_val = (linear * 255) >> FRAC_BITS;
            
            // Clamp to valid range
            if (srgb_val > 255)
                srgb_val = 255;
                
            gamma_apply = srgb_val;
        end
    endfunction
    
    // Matrix-vector multiplication - updated to be compatible with ModelSim
    function automatic [31:0] matrix_vector_multiply;
        input [31:0] matrix_00, matrix_01, matrix_02, 
                     matrix_10, matrix_11, matrix_12,
                     matrix_20, matrix_21, matrix_22;
        input [31:0] vec_0, vec_1, vec_2;
        
        // Using reg for output values instead of function output parameters
        reg [31:0] result_0_value;
        reg [31:0] result_1_value;
        reg [31:0] result_2_value;
        
        begin
            // Calculate results
            result_0_value = fp_multiply(matrix_00, vec_0) + 
                            fp_multiply(matrix_01, vec_1) + 
                            fp_multiply(matrix_02, vec_2);
                        
            result_1_value = fp_multiply(matrix_10, vec_0) + 
                            fp_multiply(matrix_11, vec_1) + 
                            fp_multiply(matrix_12, vec_2);
                        
            result_2_value = fp_multiply(matrix_20, vec_0) + 
                            fp_multiply(matrix_21, vec_1) + 
                            fp_multiply(matrix_22, vec_2);
                      
            // Copy values to the external registers
            xyz_values[31:0] = result_0_value;
            xyz_values[63:32] = result_1_value;
            xyz_values[95:64] = result_2_value;
            
            // Dummy return value
            matrix_vector_multiply = 32'd0;
        end
    endfunction
    
    // Helper functions for matrix operations
    task function_rgb_to_xyz;
        begin
            xyz_values[31:0] = fp_multiply(M_RGB_TO_XYZ_00, rgb_linear[31:0]) + 
                              fp_multiply(M_RGB_TO_XYZ_01, rgb_linear[63:32]) + 
                              fp_multiply(M_RGB_TO_XYZ_02, rgb_linear[95:64]);
                        
            xyz_values[63:32] = fp_multiply(M_RGB_TO_XYZ_10, rgb_linear[31:0]) + 
                               fp_multiply(M_RGB_TO_XYZ_11, rgb_linear[63:32]) + 
                               fp_multiply(M_RGB_TO_XYZ_12, rgb_linear[95:64]);
                        
            xyz_values[95:64] = fp_multiply(M_RGB_TO_XYZ_20, rgb_linear[31:0]) + 
                               fp_multiply(M_RGB_TO_XYZ_21, rgb_linear[63:32]) + 
                               fp_multiply(M_RGB_TO_XYZ_22, rgb_linear[95:64]);
        end
    endtask
    
    task function_apply_comp;
        begin
            xyz_adapted[31:0] = fp_multiply(comp_mat_00, xyz_values[31:0]) + 
                               fp_multiply(comp_mat_01, xyz_values[63:32]) + 
                               fp_multiply(comp_mat_02, xyz_values[95:64]);
                        
            xyz_adapted[63:32] = fp_multiply(comp_mat_10, xyz_values[31:0]) + 
                                fp_multiply(comp_mat_11, xyz_values[63:32]) + 
                                fp_multiply(comp_mat_12, xyz_values[95:64]);
                        
            xyz_adapted[95:64] = fp_multiply(comp_mat_20, xyz_values[31:0]) + 
                                fp_multiply(comp_mat_21, xyz_values[63:32]) + 
                                fp_multiply(comp_mat_22, xyz_values[95:64]);
        end
    endtask
    
    task function_xyz_to_rgb;
        begin
            rgb_linear_out[31:0] = fp_multiply(M_XYZ_TO_RGB_00, xyz_adapted[31:0]) + 
                                   fp_multiply(M_XYZ_TO_RGB_01, xyz_adapted[63:32]) + 
                                   fp_multiply(M_XYZ_TO_RGB_02, xyz_adapted[95:64]);
                        
            rgb_linear_out[63:32] = fp_multiply(M_XYZ_TO_RGB_10, xyz_adapted[31:0]) + 
                                    fp_multiply(M_XYZ_TO_RGB_11, xyz_adapted[63:32]) + 
                                    fp_multiply(M_XYZ_TO_RGB_12, xyz_adapted[95:64]);
                        
            rgb_linear_out[95:64] = fp_multiply(M_XYZ_TO_RGB_20, xyz_adapted[31:0]) + 
                                    fp_multiply(M_XYZ_TO_RGB_21, xyz_adapted[63:32]) + 
                                    fp_multiply(M_XYZ_TO_RGB_22, xyz_adapted[95:64]);
        end
    endtask
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            input_ready <= 1'b1;
            output_valid <= 1'b0;
            
            // Initialize registers
            r_in <= 8'd0;
            g_in <= 8'd0;
            b_in <= 8'd0;
            
            rgb_linear <= 96'd0;
            xyz_values <= 96'd0;
            xyz_adapted <= 96'd0;
            rgb_linear_out <= 96'd0;
            
            r_out <= 8'd0;
            g_out <= 8'd0;
            b_out <= 8'd0;
            output_rgb <= 24'd0;
        end else begin
            // Default values
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    input_ready <= 1'b1;
                    busy <= 1'b0;
                    
                    if (input_valid && matrix_valid) begin
                        // Capture input RGB
                        r_in <= input_rgb[23:16];
                        g_in <= input_rgb[15:8];
                        b_in <= input_rgb[7:0];
                        
                        input_ready <= 1'b0;
                        busy <= 1'b1;
                        state <= RGB_TO_XYZ;
                    end
                end
                
                RGB_TO_XYZ: begin
                    // Remove gamma - convert sRGB to linear RGB
                    rgb_linear[31:0] <= gamma_remove(r_in);
                    rgb_linear[63:32] <= gamma_remove(g_in);
                    rgb_linear[95:64] <= gamma_remove(b_in);
                    
                    // Convert linear RGB to XYZ - special function for this case
                    function_rgb_to_xyz;
                    
                    state <= APPLY_COMP;
                end
                
                APPLY_COMP: begin
                    // Apply chromatic adaptation matrix - special function for this case
                    function_apply_comp;
                    
                    state <= XYZ_TO_RGB;
                end
                
                XYZ_TO_RGB: begin
                    // Convert adapted XYZ back to linear RGB - special function for this case
                    function_xyz_to_rgb;
                    
                    // Apply gamma to get sRGB
                    r_out <= gamma_apply(rgb_linear_out[31:0]);
                    g_out <= gamma_apply(rgb_linear_out[63:32]);
                    b_out <= gamma_apply(rgb_linear_out[95:64]);
                    
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Output the processed RGB
                    output_rgb <= {r_out, g_out, b_out};
                    output_valid <= 1'b1;
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule 