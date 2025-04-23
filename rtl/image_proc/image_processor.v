module image_processor (
    input wire clk,
    input wire rst_n,
    
    // Input RGB data
    input wire [23:0] input_rgb,        // RGB input (8 bits per channel)
    input wire input_valid,             // Input data valid
    output reg input_ready,             // Ready to accept input
    
    // Compensation matrix
    input wire [31:0] comp_matrix [8:0], // 3x3 compensation matrix from Bradford
    input wire matrix_valid,             // Matrix is valid
    
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
    localparam [31:0] M_RGB_TO_XYZ [8:0] = '{
        32'h00006587, 32'h00003430, 32'h00000F7C,  // 0.4124, 0.2126, 0.0193
        32'h00002151, 32'h00007258, 32'h00001257,  // 0.3576, 0.7152, 0.1192
        32'h00000332, 32'h00000977, 32'h0000E357   // 0.1805, 0.0722, 0.9505
    };
    
    // XYZ to sRGB matrix (fixed-point Q16.16)
    localparam [31:0] M_XYZ_TO_RGB [8:0] = '{
        32'h00032085, 32'hFFFF0FCB, 32'hFFFFD80F,  // 3.2406, -1.5372, -0.4986
        32'hFFFF9B33, 32'h0001E5CE, 32'h00000C3C,  // -0.9689, 1.8758, 0.0415
        32'h00000830, 32'hFFFFAC0F, 32'h00010AF5   // 0.0557, -0.2040, 1.0570
    };
    
    // Internal registers
    reg [2:0] state;
    reg [7:0] r_in, g_in, b_in;           // Input RGB components
    reg [(2-0)*(31-0+1)+(31-0):0] rgb_linear;          // Linear RGB values (gamma removed)
    reg [(2-0)*(31-0+1)+(31-0):0] xyz_values;          // XYZ color space values
    reg [(2-0)*(31-0+1)+(31-0):0] xyz_adapted;         // Adapted XYZ values
    reg [(2-0)*(31-0+1)+(31-0):0] rgb_linear_out;      // Linear RGB after conversion back
    reg [7:0] r_out, g_out, b_out;        // Output RGB components
    
    // Temporary matrix calculation registers
    reg [(2-0)*(31-0+1)+(31-0):0] temp_xyz;
    
    // Fixed-point arithmetic helper functions
    function [31:0] fp_multiply;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] result;
        begin
            result = a * b;
            fp_multiply = result >> FRAC_BITS;
        end
    endtask
    
    // Gamma correction functions
    // sRGB gamma removal (approximate)
    function [31:0] gamma_remove;
        input [7:0] srgb_val;
        reg [31:0] linear;
        real normalized;
        begin
            // Convert 8-bit value to normalized range [0,1]
            normalized = srgb_val / 255.0;
            
            // Apply gamma removal
            // Simplified: if normalized < 0.04045 then normalized / 12.92
            // else ((normalized + 0.055) / 1.055)^2.4
            if (srgb_val < 11) // ~0.04045 * 255
                linear = (srgb_val << FRAC_BITS) / 255;
            else begin
                // Approximation using lookup and linear interpolation
                // would be implemented here in actual hardware
                // Simplified version:
                linear = ((srgb_val * srgb_val) << (FRAC_BITS - 8)) / 255;
            end
            
            gamma_remove = linear;
        end
    endtask
    
    // Gamma application (approximate)
    function [7:0] gamma_apply;
        input [31:0] linear;
        reg [7:0] srgb_val;
        real normalized;
        begin
            // Simplified gamma application
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
    endtask
    
    // Matrix-vector multiplication
    task matrix_vector_multiply;
        input [31:0] matrix [8:0];
        input [31:0] vector [2:0];
        output [31:0] result [2:0];
        begin
            result[0] = fp_multiply(matrix[0], vector[0]) + 
                        fp_multiply(matrix[1], vector[1]) + 
                        fp_multiply(matrix[2], vector[2]);
                        
            result[1] = fp_multiply(matrix[3], vector[0]) + 
                        fp_multiply(matrix[4], vector[1]) + 
                        fp_multiply(matrix[5], vector[2]);
                        
            result[2] = fp_multiply(matrix[6], vector[0]) + 
                        fp_multiply(matrix[7], vector[1]) + 
                        fp_multiply(matrix[8], vector[2]);
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
            
            integer i; initial i = 0; for (i = 0; i < 3; i++) begin
                rgb_linear[i] <= 32'd0;
                xyz_values[i] <= 32'd0;
                xyz_adapted[i] <= 32'd0;
                rgb_linear_out[i] <= 32'd0;
                temp_xyz[i] <= 32'd0;
            end
            
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
                    rgb_linear[0] <= gamma_remove(r_in);
                    rgb_linear[1] <= gamma_remove(g_in);
                    rgb_linear[2] <= gamma_remove(b_in);
                    
                    // Convert linear RGB to XYZ
                    matrix_vector_multiply(M_RGB_TO_XYZ, rgb_linear, xyz_values);
                    
                    state <= APPLY_COMP;
                end
                
                APPLY_COMP: begin
                    // Apply chromatic adaptation matrix
                    matrix_vector_multiply(comp_matrix, xyz_values, xyz_adapted);
                    
                    state <= XYZ_TO_RGB;
                end
                
                XYZ_TO_RGB: begin
                    // Convert adapted XYZ back to linear RGB
                    matrix_vector_multiply(M_XYZ_TO_RGB, xyz_adapted, rgb_linear_out);
                    
                    // Apply gamma to get sRGB
                    r_out <= gamma_apply(rgb_linear_out[0]);
                    g_out <= gamma_apply(rgb_linear_out[1]);
                    b_out <= gamma_apply(rgb_linear_out[2]);
                    
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