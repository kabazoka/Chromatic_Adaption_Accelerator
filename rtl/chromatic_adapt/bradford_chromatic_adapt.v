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
    
    // Fixed-point 2.0 in Q16.16 format
    localparam signed [31:0] FP_TWO = 32'h0002_0000;  // +2.0 in Q16.16
    
    // State machine definitions
    localparam IDLE = 3'd0;
    localparam CALC_REF_XYZ = 3'd1;
    localparam CALC_BRADFORD_AMB = 3'd2;
    localparam CALC_BRADFORD_REF = 3'd3;
    localparam CALC_DIAG_SCALE = 3'd4;
    localparam CALC_COMP_MATRIX = 3'd5;
    localparam DONE = 3'd6;
    
    /* ---------- Correct Bradford forward 3×3  (Row-major, Q16.16) ---------- */
    parameter signed [31:0] M_BRAD_00 = 32'h0000E525;  //  0.8951
    parameter signed [31:0] M_BRAD_01 = 32'h00004433;  //  0.2664
    parameter signed [31:0] M_BRAD_02 = 32'hFFFFD6AE;  // -0.1614

    parameter signed [31:0] M_BRAD_10 = 32'hFFFF3FF3;  // -0.7502
    parameter signed [31:0] M_BRAD_11 = 32'h0001B6A8;  //  1.7135
    parameter signed [31:0] M_BRAD_12 = 32'h00000965;  //  0.0367

    parameter signed [31:0] M_BRAD_20 = 32'h000009F5;  //  0.0389
    parameter signed [31:0] M_BRAD_21 = 32'hFFFFEE77;  // -0.0685
    parameter signed [31:0] M_BRAD_22 = 32'h00010794;  //  1.0296

    /* ---------- Inverse Bradford (from np.linalg.inv, Q16.16) -------------- */
    parameter signed [31:0] M_BRAD_INV_00 = 32'h0000FCAC; //  0.986993
    parameter signed [31:0] M_BRAD_INV_01 = 32'hFFFFDA5B; // -0.147054
    parameter signed [31:0] M_BRAD_INV_02 = 32'h000028F3; //  0.159963

    parameter signed [31:0] M_BRAD_INV_10 = 32'h00006EAC; //  0.432305
    parameter signed [31:0] M_BRAD_INV_11 = 32'h000084B3; //  0.518360
    parameter signed [31:0] M_BRAD_INV_12 = 32'h00000C9E; //  0.049291

    parameter signed [31:0] M_BRAD_INV_20 = 32'hFFFFFDD1; // -0.008529
    parameter signed [31:0] M_BRAD_INV_21 = 32'h00000A40; //  0.040043
    parameter signed [31:0] M_BRAD_INV_22 = 32'h0000F7EF; //  0.968487

    
    // Internal registers
    reg [2:0] state;
    reg [95:0] ref_xyz;                // Reference white point XYZ (packed)
    reg signed [95:0] amb_cone_resp;          // Ambient white point in cone space (packed)
    reg signed [95:0] ref_cone_resp;          // Reference white point in cone space (packed)
    reg signed [95:0] diag_scale;             // Diagonal scaling values (packed)
    reg [287:0] temp_matrix;           // Temporary matrix for calculations (packed)
    reg [287:0] temp_result;           // Temporary result for matrix calculations (packed)
    
    // CCT to XYZ converter signals
    reg cct_valid;
    wire [95:0] ref_xyz_from_cct;
    wire ref_xyz_valid;
    
    // Temporary signals for unpacking and processing
    wire [31:0] amb_x, amb_y, amb_z;
    
    integer i; // Loop counter
    
    // Extract individual components from flattened input
    assign amb_x = ambient_xyz[31:0];
    assign amb_y = ambient_xyz[63:32];
    assign amb_z = ambient_xyz[95:64];
    
    // Instantiate CCT to XYZ converter
    cct_to_xyz_converter cct_converter (
        .clk(clk),
        .rst_n(rst_n),
        .cct_in(ref_cct),
        .cct_valid(cct_valid),
        .xyz_out(ref_xyz_from_cct),
        .xyz_valid(ref_xyz_valid)
    );
    
    // Fixed-point arithmetic helper functions
    function [31:0] fp_multiply;
        input  signed [31:0] a;
        input  signed [31:0] b;
        reg    signed [63:0] result;
        begin
            result = a * b;               // Q32.32
            fp_multiply = result >>> FRAC_BITS; // keep sign (>>> = arithmetic)
        end
    endfunction

    function [31:0] fp_divide;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] temp_a;
        reg [63:0] result;
        begin
            // Debug
            $display("fp_divide: a=%h (%f), b=%h (%f)", 
                     a, $itor(a) / 65536.0, 
                     b, $itor(b) / 65536.0);
                     
            // Check for division by zero or very small values
            if ((b == 0) || (b < 32'h00000080)) begin // Avoid division by very small values
                $display("fp_divide: Division by zero or very small value detected!");
                if (a == 0)
                    result = 0; // 0/0 = 0
                else if (a[31] == b[31]) 
                    result = 64'h000000007FFFFFFF; // Max positive value
                else
                    result = 64'hFFFFFFFF80000000; // Min negative value
            end else begin
                // Perform fixed-point division
                temp_a = {32'h00000000, a};  // Extend to 64 bits
                temp_a = temp_a << FRAC_BITS;
                result = temp_a / b;
                
                // Debug
                $display("fp_divide: temp_a=%h, result=%h (%f)", 
                         temp_a, result, $itor($signed(result[31:0])) / 65536.0);
                         
                // Saturate result if it exceeds 32-bit range
                if (result > 64'h000000007FFFFFFF)
                    result = 64'h000000007FFFFFFF;
                else if (result < 64'hFFFFFFFF80000000)
                    result = 64'hFFFFFFFF80000000;
            end
            fp_divide = result[31:0];
        end
    endfunction
    
    // Saturation function to ensure values stay within valid range
    function signed [31:0] saturate;
        input signed [31:0] value;
        input signed [31:0] min_val;
        input signed [31:0] max_val;
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
            // Debug: Print ambient XYZ values
            $display("Ambient XYZ values: X=%f, Y=%f, Z=%f",
                    $itor($signed(amb_x)) / 65536.0,
                    $itor($signed(amb_y)) / 65536.0,
                    $itor($signed(amb_z)) / 65536.0);
                    
            // Convert ambient XYZ to cone responses using Bradford matrix
            // Use saturation to prevent overflow/underflow
            // -------- ambient XYZ  →  cone (LMS) -----------------
            amb_cone_resp[31:0] = saturate(
                    fp_multiply(M_BRAD_00, amb_x) +
                    fp_multiply(M_BRAD_01, amb_y) +
                    fp_multiply(M_BRAD_02, amb_z),
                    -FP_TWO, FP_TWO);   // clamp to ±2.0

            amb_cone_resp[63:32] = saturate(
                    fp_multiply(M_BRAD_10, amb_x) +
                    fp_multiply(M_BRAD_11, amb_y) +
                    fp_multiply(M_BRAD_12, amb_z),
                    -FP_TWO, FP_TWO);

            amb_cone_resp[95:64] = saturate(
                    fp_multiply(M_BRAD_20, amb_x) +
                    fp_multiply(M_BRAD_21, amb_y) +
                    fp_multiply(M_BRAD_22, amb_z),
                    -FP_TWO, FP_TWO);
                                    
            // Debug: Print Bradford matrix values
            $display("Bradford matrix:");
            $display("  [%f, %f, %f]", 
                     $itor($signed(M_BRAD_00)) / 65536.0, 
                     $itor($signed(M_BRAD_01)) / 65536.0, 
                     $itor($signed(M_BRAD_02)) / 65536.0);
            $display("  [%f, %f, %f]", 
                     $itor($signed(M_BRAD_10)) / 65536.0, 
                     $itor($signed(M_BRAD_11)) / 65536.0, 
                     $itor($signed(M_BRAD_12)) / 65536.0);
            $display("  [%f, %f, %f]", 
                     $itor($signed(M_BRAD_20)) / 65536.0, 
                     $itor($signed(M_BRAD_21)) / 65536.0, 
                     $itor($signed(M_BRAD_22)) / 65536.0);
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
                    -FP_TWO, FP_TWO);

            ref_cone_resp[63:32] = saturate(
                    fp_multiply(M_BRAD_10, ref_xyz[31:0]) +
                    fp_multiply(M_BRAD_11, ref_xyz[63:32]) +
                    fp_multiply(M_BRAD_12, ref_xyz[95:64]),
                    -FP_TWO, FP_TWO);

            ref_cone_resp[95:64] = saturate(
                    fp_multiply(M_BRAD_20, ref_xyz[31:0]) +
                    fp_multiply(M_BRAD_21, ref_xyz[63:32]) +
                    fp_multiply(M_BRAD_22, ref_xyz[95:64]),
                    -FP_TWO, FP_TWO);
        end
    endtask
    
    task calculate_diag_scale;
        begin
            // Debug: Print cone responses
            $display("Ambient cone responses: L=%f, M=%f, S=%f",
                    $itor($signed(amb_cone_resp[31:0])) / 65536.0,
                    $itor($signed(amb_cone_resp[63:32])) / 65536.0,
                    $itor($signed(amb_cone_resp[95:64])) / 65536.0);
            $display("Reference cone responses: L=%f, M=%f, S=%f",
                    $itor($signed(ref_cone_resp[31:0])) / 65536.0,
                    $itor($signed(ref_cone_resp[63:32])) / 65536.0,
                    $itor($signed(ref_cone_resp[95:64])) / 65536.0);
                    
            // Calculate diagonal scaling matrix D
            // D = diag(Ref_LMS / Amb_LMS)
            // Use division function that handles potential issues
            diag_scale[31:0] = fp_divide(ref_cone_resp[31:0], amb_cone_resp[31:0]);
            diag_scale[63:32] = fp_divide(ref_cone_resp[63:32], amb_cone_resp[63:32]);
            diag_scale[95:64] = fp_divide(ref_cone_resp[95:64], amb_cone_resp[95:64]);
            
            // Debug: Print the diagonal scale factors
            $display("Diagonal scale factors: L_scale=%f, M_scale=%f, S_scale=%f",
                    $itor($signed(diag_scale[31:0])) / 65536.0,
                    $itor($signed(diag_scale[63:32])) / 65536.0,
                    $itor($signed(diag_scale[95:64])) / 65536.0);
        end
    endtask

    // -------------------------------------------------------------------
    // Generate 3×3 Bradford chromatic-adaptation matrix (Q16.16, signed)
    // -------------------------------------------------------------------
    task calculate_comp_matrix;
        // 3×3 final output elements are all declared as signed, replacing the original unsigned
        reg signed [31:0] r00, r01, r02;
        reg signed [31:0] r10, r11, r12;
        reg signed [31:0] r20, r21, r22;

        reg signed [63:0] acc;   // 64-bit accumulator to prevent overflow when summing

        begin
            //------------------------------------------------------------
            // 1. First calculate D * M_BRADFORD (diag_scale × constant matrix)
            //------------------------------------------------------------
            temp_result[ 31:  0] = fp_multiply(diag_scale[ 31:  0], M_BRAD_00);
            temp_result[ 63: 32] = fp_multiply(diag_scale[ 31:  0], M_BRAD_01);
            temp_result[ 95: 64] = fp_multiply(diag_scale[ 31:  0], M_BRAD_02);

            temp_result[127: 96] = fp_multiply(diag_scale[ 63: 32], M_BRAD_10);
            temp_result[159:128] = fp_multiply(diag_scale[ 63: 32], M_BRAD_11);
            temp_result[191:160] = fp_multiply(diag_scale[ 63: 32], M_BRAD_12);

            temp_result[223:192] = fp_multiply(diag_scale[ 95: 64], M_BRAD_20);
            temp_result[255:224] = fp_multiply(diag_scale[ 95: 64], M_BRAD_21);
            temp_result[287:256] = fp_multiply(diag_scale[ 95: 64], M_BRAD_22);

            //------------------------------------------------------------
            // 2. M_BRAD_INV × (D·M_BRAD) — Sum three terms for each element
            //------------------------------------------------------------
            // -------- Row 0 ------------------------------------------------
            acc =   $signed(fp_multiply(M_BRAD_INV_00, temp_result[ 31:  0]))
                + $signed(fp_multiply(M_BRAD_INV_01, temp_result[127: 96]))
                + $signed(fp_multiply(M_BRAD_INV_02, temp_result[223:192]));
            r00 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_00, temp_result[ 63: 32]))
                + $signed(fp_multiply(M_BRAD_INV_01, temp_result[159:128]))
                + $signed(fp_multiply(M_BRAD_INV_02, temp_result[255:224]));
            r01 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_00, temp_result[ 95: 64]))
                + $signed(fp_multiply(M_BRAD_INV_01, temp_result[191:160]))
                + $signed(fp_multiply(M_BRAD_INV_02, temp_result[287:256]));
            r02 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            // -------- Row 1 ------------------------------------------------
            acc =   $signed(fp_multiply(M_BRAD_INV_10, temp_result[ 31:  0]))
                + $signed(fp_multiply(M_BRAD_INV_11, temp_result[127: 96]))
                + $signed(fp_multiply(M_BRAD_INV_12, temp_result[223:192]));
            r10 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_10, temp_result[ 63: 32]))
                + $signed(fp_multiply(M_BRAD_INV_11, temp_result[159:128]))
                + $signed(fp_multiply(M_BRAD_INV_12, temp_result[255:224]));
            r11 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_10, temp_result[ 95: 64]))
                + $signed(fp_multiply(M_BRAD_INV_11, temp_result[191:160]))
                + $signed(fp_multiply(M_BRAD_INV_12, temp_result[287:256]));
            r12 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            // -------- Row 2 ------------------------------------------------
            acc =   $signed(fp_multiply(M_BRAD_INV_20, temp_result[ 31:  0]))
                + $signed(fp_multiply(M_BRAD_INV_21, temp_result[127: 96]))
                + $signed(fp_multiply(M_BRAD_INV_22, temp_result[223:192]));
            r20 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_20, temp_result[ 63: 32]))
                + $signed(fp_multiply(M_BRAD_INV_21, temp_result[159:128]))
                + $signed(fp_multiply(M_BRAD_INV_22, temp_result[255:224]));
            r21 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            acc =   $signed(fp_multiply(M_BRAD_INV_20, temp_result[ 95: 64]))
                + $signed(fp_multiply(M_BRAD_INV_21, temp_result[191:160]))
                + $signed(fp_multiply(M_BRAD_INV_22, temp_result[287:256]));
            r22 = saturate(acc[47:16], -FP_TWO, FP_TWO);

            //------------------------------------------------------------
            // 3. Pack 3×3 → 288-bit bus (row-major order)
            //------------------------------------------------------------
            comp_matrix[ 31:  0] = r00;  comp_matrix[ 63: 32] = r01;  comp_matrix[ 95: 64] = r02;
            comp_matrix[127: 96] = r10;  comp_matrix[159:128] = r11;  comp_matrix[191:160] = r12;
            comp_matrix[223:192] = r20;  comp_matrix[255:224] = r21;  comp_matrix[287:256] = r22;

    `ifdef SIM
            // -------- Optional debug print (ModelSim/Questa) -------------
            $display("Bradford comp-matrix (Q16.16):");
            $display("[%f %f %f]",
                    $itor($signed(r00))/65536.0, $itor($signed(r01))/65536.0, $itor($signed(r02))/65536.0);
            $display("[%f %f %f]",
                    $itor($signed(r10))/65536.0, $itor($signed(r11))/65536.0, $itor($signed(r12))/65536.0);
            $display("[%f %f %f]",
                    $itor($signed(r20))/65536.0, $itor($signed(r21))/65536.0, $itor($signed(r22))/65536.0);
    `endif
        end
    endtask


    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            matrix_valid <= 1'b0;
            cct_valid <= 1'b0;
            
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
            cct_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (xyz_valid) begin
                        // Start CCT to XYZ conversion process
                        cct_valid <= 1'b1;
                        state <= CALC_REF_XYZ;
                    end
                end
                
                CALC_REF_XYZ: begin
                    // Wait for CCT converter to provide valid XYZ values
                    cct_valid <= 1'b0;
                    
                    if (ref_xyz_valid) begin
                        // Capture the XYZ values from the converter
                        ref_xyz <= ref_xyz_from_cct;
                        
                        // Log the XYZ values derived from CCT
                        $display("CCT: %dK, Generated reference white point: X=%f, Y=%f, Z=%f", 
                                ref_cct,
                                $itor(ref_xyz_from_cct[31:0]) / 65536.0,
                                $itor(ref_xyz_from_cct[63:32]) / 65536.0,
                                $itor(ref_xyz_from_cct[95:64]) / 65536.0);
                        
                        // Debug: Print ambient XYZ values for comparison
                        $display("Ambient white point: X=%f, Y=%f, Z=%f", 
                                $itor(amb_x) / 65536.0,
                                $itor(amb_y) / 65536.0,
                                $itor(amb_z) / 65536.0);
                                
                        // Verify reference values are non-zero
                        if (ref_xyz_from_cct[31:0] == 0 || ref_xyz_from_cct[63:32] == 0 || ref_xyz_from_cct[95:64] == 0) begin
                            $display("ERROR: Reference XYZ contains zero values. Using fallback reference.");
                            // Use D65 reference if converter returns zeros
                            ref_xyz[31:0] <= 32'h0000F333;    // X = 0.95047
                            ref_xyz[63:32] <= 32'h00010000;   // Y = 1.0
                            ref_xyz[95:64] <= 32'h00011666;   // Z = 1.08883
                        end
                        
                        state <= CALC_BRADFORD_AMB;
                    end
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