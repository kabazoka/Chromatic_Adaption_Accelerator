`timescale 1ns / 1ps

module bradford_chromatic_adapt_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    parameter Q_FRAC_BITS = 16;
    parameter FLOAT_TOLERANCE = 0.001; // Tolerance for floating point comparisons
    
    // Signals
    reg clk;
    reg rst_n;
    reg [95:0] ambient_xyz_packed; // Corrected: Use a packed vector for the UUT port
    reg xyz_valid;
    reg [15:0] ref_cct;
    wire [287:0] comp_matrix_packed; // Corrected: Use a packed vector from UUT
    wire matrix_valid;
    
    integer test_num = 0;
    integer errors = 0;

    // Instantiate the Unit Under Test (UUT)
    bradford_chromatic_adapt uut (
        .clk(clk),
        .rst_n(rst_n),
        .ambient_xyz(ambient_xyz_packed), // Corrected
        .xyz_valid(xyz_valid),
        .ref_cct(ref_cct),
        .comp_matrix(comp_matrix_packed), // Corrected
        .matrix_valid(matrix_valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper functions
    function real fixed_to_float;
        input [31:0] fixed_point;
        begin
            // Convert QN.FRAC_BITS to float
            fixed_to_float = $signed(fixed_point) / (2.0**Q_FRAC_BITS);
        end
    endfunction
    
    // Helper task to check a matrix element
    task check_matrix_element;
        // This task now only increments the error counter.
        // The comparison and detailed $display are done in the calling task.
        begin
            errors = errors + 1;
        end
    endtask

    // Helper task to run a test case and check results
    task run_and_check_test;
        input [15:0] current_ref_cct;
        input [31:0] amb_x_q16, amb_y_q16, amb_z_q16;
        input real exp_m00, exp_m01, exp_m02;
        input real exp_m10, exp_m11, exp_m12;
        input real exp_m20, exp_m21, exp_m22;

        begin
            test_num = test_num + 1;
            $display("--------------------------------------------------------------------");
            $display("Time %0t: Starting Test %0d: Ambient XYZ (Q16.16): X=0x%h (%f), Y=0x%h (%f), Z=0x%h (%f)",
                     $time, test_num, amb_x_q16, fixed_to_float(amb_x_q16),
                     amb_y_q16, fixed_to_float(amb_y_q16),
                     amb_z_q16, fixed_to_float(amb_z_q16));
            $display("Target Reference CCT: %0d K", current_ref_cct);

            ambient_xyz_packed[31:0]   = amb_x_q16;
            ambient_xyz_packed[63:32]  = amb_y_q16;
            ambient_xyz_packed[95:64]  = amb_z_q16;
            ref_cct = current_ref_cct;
            xyz_valid = 1;
            #(CLK_PERIOD); // Assert valid for one cycle
            xyz_valid = 0;

            // Wait for matrix calculation
            wait(matrix_valid);
            #(CLK_PERIOD/4); // Allow signals to settle if matrix_valid is combinational with outputs

            $display("Time %0t: Test %0d: Compensation Matrix Calculation Complete.", $time, test_num);

            // Display key internal UUT signals (hierarchical access)
            // Note: Hierarchical paths might need adjustment based on simulator/synthesis tools
            // These are critical for debugging the CCT processing path
            $display("UUT Internal ref_xyz_from_cct (Q16.16): X=0x%h (%f), Y=0x%h (%f), Z=0x%h (%f)",
                     uut.ref_xyz_from_cct[31:0], fixed_to_float(uut.ref_xyz_from_cct[31:0]),
                     uut.ref_xyz_from_cct[63:32], fixed_to_float(uut.ref_xyz_from_cct[63:32]),
                     uut.ref_xyz_from_cct[95:64], fixed_to_float(uut.ref_xyz_from_cct[95:64]));
            $display("UUT Internal ref_xyz (latched) (Q16.16): X=0x%h (%f), Y=0x%h (%f), Z=0x%h (%f)",
                     uut.ref_xyz[31:0], fixed_to_float(uut.ref_xyz[31:0]),
                     uut.ref_xyz[63:32], fixed_to_float(uut.ref_xyz[63:32]),
                     uut.ref_xyz[95:64], fixed_to_float(uut.ref_xyz[95:64]));
            $display("UUT Internal amb_cone_resp (LMS, Q16.16): L=0x%h (%f), M=0x%h (%f), S=0x%h (%f)",
                     uut.amb_cone_resp[31:0], fixed_to_float(uut.amb_cone_resp[31:0]),
                     uut.amb_cone_resp[63:32], fixed_to_float(uut.amb_cone_resp[63:32]),
                     uut.amb_cone_resp[95:64], fixed_to_float(uut.amb_cone_resp[95:64]));
            $display("UUT Internal ref_cone_resp (LMS, Q16.16): L=0x%h (%f), M=0x%h (%f), S=0x%h (%f)",
                     uut.ref_cone_resp[31:0], fixed_to_float(uut.ref_cone_resp[31:0]),
                     uut.ref_cone_resp[63:32], fixed_to_float(uut.ref_cone_resp[63:32]),
                     uut.ref_cone_resp[95:64], fixed_to_float(uut.ref_cone_resp[95:64]));
            $display("UUT Internal diag_scale (LMS, Q16.16): Ls=0x%h (%f), Ms=0x%h (%f), Ss=0x%h (%f)",
                     uut.diag_scale[31:0], fixed_to_float(uut.diag_scale[31:0]),
                     uut.diag_scale[63:32], fixed_to_float(uut.diag_scale[63:32]),
                     uut.diag_scale[95:64], fixed_to_float(uut.diag_scale[95:64]));

            $display("Resulting Compensation Matrix (Float):");
            $display("  [%f, %f, %f]",
                     fixed_to_float(comp_matrix_packed[31:0]),   // M00
                     fixed_to_float(comp_matrix_packed[63:32]),  // M01
                     fixed_to_float(comp_matrix_packed[95:64])); // M02
            $display("  [%f, %f, %f]",
                     fixed_to_float(comp_matrix_packed[127:96]),  // M10
                     fixed_to_float(comp_matrix_packed[159:128]), // M11
                     fixed_to_float(comp_matrix_packed[191:160]));// M12
            $display("  [%f, %f, %f]",
                     fixed_to_float(comp_matrix_packed[223:192]), // M20
                     fixed_to_float(comp_matrix_packed[255:224]), // M21
                     fixed_to_float(comp_matrix_packed[287:256]));// M22

            // Check against expected values
            // IMPORTANT: Replace 0.0 with actual pre-calculated expected float values
            if ($abs(fixed_to_float(comp_matrix_packed[31:0]) - exp_m00) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M00 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[31:0]), exp_m00);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[63:32]) - exp_m01) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M01 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[63:32]), exp_m01);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[95:64]) - exp_m02) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M02 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[95:64]), exp_m02);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[127:96]) - exp_m10) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M10 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[127:96]), exp_m10);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[159:128]) - exp_m11) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M11 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[159:128]), exp_m11);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[191:160]) - exp_m12) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M12 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[191:160]), exp_m12);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[223:192]) - exp_m20) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M20 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[223:192]), exp_m20);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[255:224]) - exp_m21) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M21 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[255:224]), exp_m21);
                check_matrix_element(); // Call with no arguments
            end
            if ($abs(fixed_to_float(comp_matrix_packed[287:256]) - exp_m22) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: M22 mismatch. Actual: %f, Expected: %f", test_num, fixed_to_float(comp_matrix_packed[287:256]), exp_m22);
                check_matrix_element(); // Call with no arguments
            end

            #100; // Delay between tests
        end
    endtask

    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("bradford_chromatic_adapt_tb.vcd");
        $dumpvars(0, bradford_chromatic_adapt_tb);
        
        // Initialize inputs
        rst_n = 0;
        ambient_xyz_packed = 96'd0;
        xyz_valid = 0;
        ref_cct = 16'd6500; // Default
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // --- Test Cases ---
        // IMPORTANT: Expected matrix values (exp_mNN) are illustrative (0.0)
        // and MUST be replaced with actual pre-calculated values for meaningful checks.

        // Test Case 1: Ambient D50 (approx) to Target D65 (6500K)
        // D50 XYZ (Y=1): X=0.9642, Y=1.0000, Z=0.8249
        // Q16.16: X=0xF6E2, Y=0x10000, Z=0xD32B
        run_and_check_test(
            16'd6500, // ref_cct
            32'h0000F6E2, 32'h00010000, 32'h0000D32B, // ambient XYZ for D50
            // "Ambient D50 (XYZ:0.9642,1,0.8249) to Target D65 (6500K)", // Test description moved to $display
            // Replace with actual expected values for D50 -> D65
            1.036, -0.023, -0.011,   // M00, M01, M02 (Illustrative - NEED CALCULATION)
           -0.032,  1.019,  0.010,   // M10, M11, M12 (Illustrative - NEED CALCULATION)
            0.002, -0.003,  0.919    // M20, M21, M22 (Illustrative - NEED CALCULATION)
        );

        // Test Case 2: Ambient D65 (approx) to Target D50 (5000K)
        // D65 XYZ (Y=1): X=0.95047, Y=1.0000, Z=1.08883
        // Q16.16: X=0xF352, Y=0x10000, Z=0x116A0 (approx)
        run_and_check_test(
            16'd5000, // ref_cct
            32'h0000F352, 32'h00010000, 32'h000116A0, // ambient XYZ for D65
            // "Ambient D65 (XYZ:0.9505,1,1.0888) to Target D50 (5000K)", // Test description moved to $display
            // Replace with actual expected values for D65 -> D50
            0.964,  0.024,  0.010,   // M00, M01, M02 (Illustrative - NEED CALCULATION)
            0.031,  0.980, -0.009,   // M10, M11, M12 (Illustrative - NEED CALCULATION)
           -0.002,  0.003,  1.088    // M20, M21, M22 (Illustrative - NEED CALCULATION)
        );

        // Test Case 3: Ambient D50 to Target D50 (should be identity-like matrix)
        run_and_check_test(
            16'd5000, // ref_cct
            32'h0000F6E2, 32'h00010000, 32'h0000D32B, // ambient XYZ for D50
            // "Ambient D50 to Target D50 (5000K) - Expect Identity-like", // Test description moved to $display
            // Expected: Close to Identity Matrix
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0
        );
        
        // Test Case 4: Original Test Case 1: "5000K" ambient (as per original TB) to Target D65
        // Original values: X=1.199997 (0x13333), Y=1.0 (0x10000), Z=0.699997 (0xB333)
        // These XYZ for "5000K" are different from standard D50.
        run_and_check_test(
            16'd6500, // ref_cct
            32'h00013333, 32'h00010000, 32'h0000B333,
            // "Ambient \'Custom 5000K\' (XYZ:1.2,1,0.7) to Target D65 (6500K)", // Test description moved to $display
            // Replace with actual expected values
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 // Placeholder
        );

        // Test Case 5: Original Test Case 2: "3000K" ambient to Target D65
        // Original values: X=1.479996 (0x17AE1), Y=1.0 (0x10000), Z=0.360001 (0x5C29)
        run_and_check_test(
            16'd6500, // ref_cct
            32'h00017AE1, 32'h00010000, 32'h00005C29,
            // "Ambient \'Custom 3000K\' (XYZ:1.48,1,0.36) to Target D65 (6500K)", // Test description moved to $display
            // Replace with actual expected values
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 // Placeholder
        );
        
        // Test Case 6: Ambient D65 to Target D80 (8000K) - New test for varying ref_cct
        run_and_check_test(
            16'd8000, // ref_cct
            32'h0000F352, 32'h00010000, 32'h000116A0, // ambient XYZ for D65
            // "Ambient D65 to Target D80 (8000K)", // Test description moved to $display
            // Replace with actual expected values for D65 -> D80
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 // Placeholder
        );

        // End simulation
        $display("--------------------------------------------------------------------");
        if (errors == 0) begin
            $display("All %0d tests PASSED.", test_num);
        end else begin
            $display("%0d out of %0d tests FAILED.", errors, test_num);
        end
        $display("Simulation completed at %0t", $time);
        $finish;
    end
    
    // Monitor matrix validity
    always @(posedge matrix_valid) begin
        $display("Info: Time %0t: Compensation matrix calculation complete flag (matrix_valid asserted)", $time);
    end

endmodule 