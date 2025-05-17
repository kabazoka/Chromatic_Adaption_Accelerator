module bradford_chromatic_adapt (
    input wire clk,
    input wire rst_n,
    
    // Input ambient white point in XYZ
    input wire [95:0] ambient_xyz,    // X, Y, Z in fixed-point
    input wire xyz_valid,             // Input is valid
    
    // Reference CCT (typically D65 - 6500K)
    input wire [15:0] ref_cct,        // Reference CCT in Kelvin
    
    // Output compensation matrix
    output reg [287:0] comp_matrix,   // 3x3 matrix in fixed-point
    output reg matrix_valid           // Matrix is valid
);

    // Fixed-point format settings (Q16.16)
    localparam INT_BITS = 16;
    localparam FRAC_BITS = 16;
    localparam Q_FORMAT = 32;  // Total bits
    
    // Fixed-point 1.0 in Q16.16 format
    localparam FP_ONE = 32'h00010000;
    
    // State machine definitions
    localparam IDLE = 3'd0;
    localparam CALC_REF_XYZ = 3'd1;
    localparam CALC_BRADFORD_AMB = 3'd2;
    localparam CALC_BRADFORD_REF = 3'd3;
    localparam CALC_DIAG_SCALE = 3'd4;
    localparam CALC_COMP_MATRIX = 3'd5;
    localparam DONE = 3'd6;
    
    // Bradford transformation matrix (fixed-point Q16.16)
    // This is the linear RGB to LMS matrix for the Bradford transform
    parameter M_BRAD_00 = 32'h0000E505; // 0.8951
    parameter M_BRAD_01 = 32'hFFFF3F7C; // -0.7502
    parameter M_BRAD_02 = 32'hFFFFDC29; // -0.1380
    parameter M_BRAD_10 = 32'h00000444; // 0.2664
    parameter M_BRAD_11 = 32'h00017751; // 1.7135
    parameter M_BRAD_12 = 32'hFFFFF548; // -0.0415
    parameter M_BRAD_20 = 32'hFFFFD70A; // -0.1614
    parameter M_BRAD_21 = 32'h00000962; // 0.0367
    parameter M_BRAD_22 = 32'h00011C29; // 1.1082
    
    // Inverse Bradford transformation matrix (fixed-point Q16.16)
    parameter M_BRAD_INV_00 = 32'h0000FC8F; // 0.9869
    parameter M_BRAD_INV_01 = 32'h00007D70; // 0.4898
    parameter M_BRAD_INV_02 = 32'h0000228F; // 0.1368
    parameter M_BRAD_INV_10 = 32'h00008A33; // 0.5403
    parameter M_BRAD_INV_11 = 32'h0000A63D; // 0.6499
    parameter M_BRAD_INV_12 = 32'hFFFFE6E1; // -0.0967
    parameter M_BRAD_INV_20 = 32'h0000009E; // 0.0060
    parameter M_BRAD_INV_21 = 32'hFFFFCD70; // -0.1976
    parameter M_BRAD_INV_22 = 32'h0000E7D7; // 0.9054
    
    // Internal registers
    reg [2:0] state;
    reg [95:0] ref_xyz;                // Reference white point XYZ (packed)
    reg [95:0] amb_cone_resp;          // Ambient white point in cone space (packed)
    reg [95:0] ref_cone_resp;          // Reference white point in cone space (packed)
    reg [95:0] diag_scale;             // Diagonal scaling values (packed)
    reg [287:0] temp_matrix;           // Temporary matrix for calculations (packed)
    reg [287:0] temp_result;           // Temporary result for matrix calculations (packed)
    
    // Temporary signals for unpacking and processing
    wire [31:0] amb_x, amb_y, amb_z;
    
    integer i; // Loop counter
    
    // Extract individual components from flattened input
    assign amb_x = ambient_xyz[31:0];
    assign amb_y = ambient_xyz[63:32];
    assign amb_z = ambient_xyz[95:64];
    
    // Fixed-point arithmetic helper functions
    function [31:0] fp_multiply;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] result;
        begin
            result = a * b;
            fp_multiply = result[47:16]; // Extract appropriate bits for Q16.16
        end
    endfunction
    
    function [31:0] fp_divide;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] result;
        begin
            // Check for division by zero or very small values
            if ((b == 0) || (b < 32'h00000010)) // Avoid division by very small values
                result = (a[31] == b[31]) ? 64'h7FFFFFFFFFFFFFFF : 64'h8000000000000000; // Max or min value based on sign
            else begin
                result = (a << FRAC_BITS) / b;
                // Saturate result if it overflows 32 bits
                if (result > 64'h00000000FFFFFFFF)
                    result = 64'h00000000FFFFFFFF;
                else if (result < 64'hFFFFFFFF00000000)
                    result = 64'hFFFFFFFF00000000;
            end
            fp_divide = result[31:0];
        end
    endfunction
    
    // Saturation function to ensure values stay within valid range
    function [31:0] saturate;
        input [31:0] value;
        input [31:0] min_val;
        input [31:0] max_val;
        begin
            if (value < min_val)
                saturate = min_val;
            else if (value > max_val)
                saturate = max_val;
            else
                saturate = value;
        end
    endfunction
    
    // Helper tasks for calculating matrix operations
    task matrix_vector_multiply_amb;
        begin
            // Convert ambient XYZ to cone responses using Bradford matrix
            // Use saturation to prevent overflow/underflow
            amb_cone_resp[31:0] = saturate(
                                    fp_multiply(M_BRAD_00, amb_x) + 
                                    fp_multiply(M_BRAD_01, amb_y) + 
                                    fp_multiply(M_BRAD_02, amb_z),
                                    32'h80000000, 32'h7FFFFFFF);
                        
            amb_cone_resp[63:32] = saturate(
                                    fp_multiply(M_BRAD_10, amb_x) + 
                                    fp_multiply(M_BRAD_11, amb_y) + 
                                    fp_multiply(M_BRAD_12, amb_z),
                                    32'h80000000, 32'h7FFFFFFF);
                        
            amb_cone_resp[95:64] = saturate(
                                    fp_multiply(M_BRAD_20, amb_x) + 
                                    fp_multiply(M_BRAD_21, amb_y) + 
                                    fp_multiply(M_BRAD_22, amb_z),
                                    32'h80000000, 32'h7FFFFFFF);
        end
    endtask
    
    task matrix_vector_multiply_ref;
        begin
            // Convert reference XYZ to cone responses using Bradford matrix
            // Use saturation to prevent overflow/underflow
            ref_cone_resp[31:0] = saturate(
                                    fp_multiply(M_BRAD_00, ref_xyz[31:0]) + 
                                    fp_multiply(M_BRAD_01, ref_xyz[63:32]) + 
                                    fp_multiply(M_BRAD_02, ref_xyz[95:64]),
                                    32'h80000000, 32'h7FFFFFFF);
                        
            ref_cone_resp[63:32] = saturate(
                                    fp_multiply(M_BRAD_10, ref_xyz[31:0]) + 
                                    fp_multiply(M_BRAD_11, ref_xyz[63:32]) + 
                                    fp_multiply(M_BRAD_12, ref_xyz[95:64]),
                                    32'h80000000, 32'h7FFFFFFF);
                        
            ref_cone_resp[95:64] = saturate(
                                    fp_multiply(M_BRAD_20, ref_xyz[31:0]) + 
                                    fp_multiply(M_BRAD_21, ref_xyz[63:32]) + 
                                    fp_multiply(M_BRAD_22, ref_xyz[95:64]),
                                    32'h80000000, 32'h7FFFFFFF);
        end
    endtask
    
    task calculate_diag_scale;
        begin
            // Calculate diagonal scaling matrix D
            // D = diag(Ref_LMS / Amb_LMS)
            // Use division function that handles potential issues
            diag_scale[31:0] = fp_divide(ref_cone_resp[31:0], amb_cone_resp[31:0]);
            diag_scale[63:32] = fp_divide(ref_cone_resp[63:32], amb_cone_resp[63:32]);
            diag_scale[95:64] = fp_divide(ref_cone_resp[95:64], amb_cone_resp[95:64]);
        end
    endtask

    task calculate_comp_matrix;
        reg [31:0] r00, r01, r02, r10, r11, r12, r20, r21, r22;
        begin
            // Create diagonal scaling matrix
            temp_matrix[31:0] = diag_scale[31:0];
            temp_matrix[63:32] = 32'd0;
            temp_matrix[95:64] = 32'd0;
            temp_matrix[127:96] = 32'd0;
            temp_matrix[159:128] = diag_scale[63:32];
            temp_matrix[191:160] = 32'd0;
            temp_matrix[223:192] = 32'd0;
            temp_matrix[255:224] = 32'd0;
            temp_matrix[287:256] = diag_scale[95:64];
            
            // D * M_BRADFORD
            temp_result[31:0] = fp_multiply(diag_scale[31:0], M_BRAD_00);
            temp_result[63:32] = fp_multiply(diag_scale[31:0], M_BRAD_01);
            temp_result[95:64] = fp_multiply(diag_scale[31:0], M_BRAD_02);
            
            temp_result[127:96] = fp_multiply(diag_scale[63:32], M_BRAD_10);
            temp_result[159:128] = fp_multiply(diag_scale[63:32], M_BRAD_11);
            temp_result[191:160] = fp_multiply(diag_scale[63:32], M_BRAD_12);
            
            temp_result[223:192] = fp_multiply(diag_scale[95:64], M_BRAD_20);
            temp_result[255:224] = fp_multiply(diag_scale[95:64], M_BRAD_21);
            temp_result[287:256] = fp_multiply(diag_scale[95:64], M_BRAD_22);
            
            // Then M_BRADFORD_INV * (D * M_BRADFORD)
            // Row 1
            r00 = saturate(
                  fp_multiply(M_BRAD_INV_00, temp_result[31:0]) + 
                  fp_multiply(M_BRAD_INV_01, temp_result[127:96]) + 
                  fp_multiply(M_BRAD_INV_02, temp_result[223:192]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r01 = saturate(
                  fp_multiply(M_BRAD_INV_00, temp_result[63:32]) + 
                  fp_multiply(M_BRAD_INV_01, temp_result[159:128]) + 
                  fp_multiply(M_BRAD_INV_02, temp_result[255:224]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r02 = saturate(
                  fp_multiply(M_BRAD_INV_00, temp_result[95:64]) + 
                  fp_multiply(M_BRAD_INV_01, temp_result[191:160]) + 
                  fp_multiply(M_BRAD_INV_02, temp_result[287:256]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            // Row 2
            r10 = saturate(
                  fp_multiply(M_BRAD_INV_10, temp_result[31:0]) + 
                  fp_multiply(M_BRAD_INV_11, temp_result[127:96]) + 
                  fp_multiply(M_BRAD_INV_12, temp_result[223:192]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r11 = saturate(
                  fp_multiply(M_BRAD_INV_10, temp_result[63:32]) + 
                  fp_multiply(M_BRAD_INV_11, temp_result[159:128]) + 
                  fp_multiply(M_BRAD_INV_12, temp_result[255:224]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r12 = saturate(
                  fp_multiply(M_BRAD_INV_10, temp_result[95:64]) + 
                  fp_multiply(M_BRAD_INV_11, temp_result[191:160]) + 
                  fp_multiply(M_BRAD_INV_12, temp_result[287:256]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            // Row 3
            r20 = saturate(
                  fp_multiply(M_BRAD_INV_20, temp_result[31:0]) + 
                  fp_multiply(M_BRAD_INV_21, temp_result[127:96]) + 
                  fp_multiply(M_BRAD_INV_22, temp_result[223:192]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r21 = saturate(
                  fp_multiply(M_BRAD_INV_20, temp_result[63:32]) + 
                  fp_multiply(M_BRAD_INV_21, temp_result[159:128]) + 
                  fp_multiply(M_BRAD_INV_22, temp_result[255:224]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            r22 = saturate(
                  fp_multiply(M_BRAD_INV_20, temp_result[95:64]) + 
                  fp_multiply(M_BRAD_INV_21, temp_result[191:160]) + 
                  fp_multiply(M_BRAD_INV_22, temp_result[287:256]),
                  32'h80000000, 32'h7FFFFFFF);
                  
            // Flatten the matrix for output
            comp_matrix[31:0]     = r00;
            comp_matrix[63:32]    = r01;
            comp_matrix[95:64]    = r02;
            comp_matrix[127:96]   = r10;
            comp_matrix[159:128]  = r11;
            comp_matrix[191:160]  = r12;
            comp_matrix[223:192]  = r20;
            comp_matrix[255:224]  = r21;
            comp_matrix[287:256]  = r22;
        end
    endtask

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            matrix_valid <= 1'b0;
            
            // Initialize registers
            ref_xyz <= 96'd0;
            amb_cone_resp <= 96'd0;
            ref_cone_resp <= 96'd0;
            diag_scale <= 96'd0;
            temp_matrix <= 288'd0;
            temp_result <= 288'd0;
            comp_matrix <= 288'd0;
        end else begin
            // Default values
            matrix_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (xyz_valid) begin
                        state <= CALC_REF_XYZ;
                    end
                end
                
                CALC_REF_XYZ: begin
                    // In a real implementation, would convert reference CCT to XYZ
                    // For simplicity, use D65 white point (x=0.3127, y=0.3290, Y=1.0)
                    // Convert to XYZ: X = (x/y)*Y, Z = ((1-x-y)/y)*Y
                    
                    // Hardcoded D65 white point in fixed-point - corrected values
                    ref_xyz[31:0] <= 32'h0000F333; // X = 0.95047 in Q16.16
                    ref_xyz[63:32] <= FP_ONE;      // Y = 1.0 in Q16.16
                    ref_xyz[95:64] <= 32'h00011666; // Z = 1.08883 in Q16.16
                    
                    state <= CALC_BRADFORD_AMB;
                end
                
                CALC_BRADFORD_AMB: begin
                    // Convert ambient XYZ to cone responses using Bradford matrix
                    matrix_vector_multiply_amb;
                    state <= CALC_BRADFORD_REF;
                end
                
                CALC_BRADFORD_REF: begin
                    // Convert reference XYZ to cone responses using Bradford matrix
                    matrix_vector_multiply_ref;
                    state <= CALC_DIAG_SCALE;
                end
                
                CALC_DIAG_SCALE: begin
                    // Calculate diagonal scaling matrix D
                    calculate_diag_scale;
                    state <= CALC_COMP_MATRIX;
                end
                
                CALC_COMP_MATRIX: begin
                    // Calculate the full compensation matrix
                    calculate_comp_matrix;
                    state <= DONE;
                end
                
                DONE: begin
                    matrix_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule 