`timescale 1ns / 1ps

module cct_to_xyz_converter_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    parameter Q_FRAC_BITS = 16;
    parameter FLOAT_TOLERANCE = 0.001; // Tolerance for floating point comparisons

    // Signals
    reg clk;
    reg rst_n;
    reg [15:0] cct_in_tb; // Renamed to avoid conflict if ever hierarchical
    reg cct_valid_tb;  // Renamed

    wire [95:0] xyz_out_packed; // Corrected: UUT outputs a packed 96-bit vector
    wire xyz_valid_uut;  // Renamed

    integer test_num = 0;
    integer errors = 0;

    // Instantiate the Unit Under Test (UUT)
    cct_to_xyz_converter uut (
        .clk(clk),
        .rst_n(rst_n),
        .cct_in(cct_in_tb),
        .cct_valid(cct_valid_tb),
        .xyz_out(xyz_out_packed), // Corrected port connection
        .xyz_valid(xyz_valid_uut)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper functions to convert fixed-point to float for display
    function real fixed_to_float;
        input [31:0] fixed_point;
        begin
            fixed_to_float = $signed(fixed_point) / (2.0**Q_FRAC_BITS); // Q16.16 format
        end
    endfunction

    // Task to run a single CCT test and check results
    task run_and_check_cct_test;
        input [15:0] cct_val;
        input real expected_x_float;
        input real expected_y_float;
        input real expected_z_float;

        reg [31:0] actual_x_q16;
        reg [31:0] actual_y_q16;
        reg [31:0] actual_z_q16;
        real actual_x_float;
        real actual_y_float;
        real actual_z_float;

        begin
            test_num = test_num + 1;
            $display("--------------------------------------------------------------------");
            $display("Time %0t: Test %0d: %0d K", $time, test_num, cct_val);

            cct_in_tb = cct_val;
            cct_valid_tb = 1;
            #(CLK_PERIOD);
            cct_valid_tb = 0;

            wait(xyz_valid_uut); // Wait for UUT to signal data is valid
             #(CLK_PERIOD/4); // Allow signals to settle

            // Unpack the 96-bit output from UUT
            actual_x_q16 = xyz_out_packed[31:0];
            actual_y_q16 = xyz_out_packed[63:32];
            actual_z_q16 = xyz_out_packed[95:64];

            actual_x_float = fixed_to_float(actual_x_q16);
            actual_y_float = fixed_to_float(actual_y_q16);
            actual_z_float = fixed_to_float(actual_z_q16);
            
            $display("Time %0t: Test %0d: CCT_uut_internal = %0d K", $time, test_num, uut.cct_value); // Display internal CCT used
            $display("                     x_coord_internal = %f, y_coord_internal = %f", fixed_to_float(uut.x_coord), fixed_to_float(uut.y_coord));
            $display("                     Actual XYZ (float): X=%f, Y=%f, Z=%f", actual_x_float, actual_y_float, actual_z_float);
            $display("                     Expected XYZ (float): X=%f, Y=%f, Z=%f", expected_x_float, expected_y_float, expected_z_float);

            // Check X
            if ($abs(actual_x_float - expected_x_float) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: X mismatch. Actual: %f, Expected: %f", test_num, actual_x_float, expected_x_float);
                errors = errors + 1;
            end
            // Check Y
            if ($abs(actual_y_float - expected_y_float) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: Y mismatch. Actual: %f, Expected: %f", test_num, actual_y_float, expected_y_float);
                errors = errors + 1;
            end
            // Check Z
            if ($abs(actual_z_float - expected_z_float) > FLOAT_TOLERANCE) begin
                $display("ERROR Test %0d: Z mismatch. Actual: %f, Expected: %f", test_num, actual_z_float, expected_z_float);
                errors = errors + 1;
            end
            #100; // Delay between tests
        end
    endtask

    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("cct_to_xyz_converter_tb.vcd");
        $dumpvars(0, cct_to_xyz_converter_tb);
        
        // Initialize inputs
        rst_n = 0;
        cct_in_tb = 0;
        cct_valid_tb = 0;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Expected values based on current RTL cct_to_xyz_converter.v logic:
        // D65 (e.g. 6500K): x=0.3127, y=0.3290  => X=0.95045, Y=1.0, Z=1.08829
        // D50 (e.g. 5000K or 3000K): x=0.3608, y=0.3609 => X=0.99972, Y=1.0, Z=0.76891
        // Dxx (e.g. 8000K): x=0.3324, y=0.3474 => X=0.95681, Y=1.0, Z=0.92066

        // $display("Starting Test: 3000K (Uses D50 approx)"); // Optional: Add manual description
        run_and_check_cct_test(16'd3000, 0.99972, 1.0, 0.76891);
        // $display("Starting Test: 5000K (Uses D50 approx)"); // Optional: Add manual description
        run_and_check_cct_test(16'd5000, 0.99972, 1.0, 0.76891);
        // $display("Starting Test: 6500K (D65 approx)"); // Optional: Add manual description
        run_and_check_cct_test(16'd6500, 0.95045, 1.0, 1.08829);
        // $display("Starting Test: 8000K (Uses Dxx approx, CCT_MAX)"); // Optional: Add manual description
        run_and_check_cct_test(16'd8000, 0.95681, 1.0, 0.92066);

        // Test boundary conditions for clamping in UUT
        // $display("Starting Test: 2500K (Should clamp to 3000K, D50 approx)"); // Optional: Add manual description
        run_and_check_cct_test(16'd2500, 0.99972, 1.0, 0.76891);
        // $display("Starting Test: 9000K (Should clamp to 8000K, Dxx approx)"); // Optional: Add manual description
        run_and_check_cct_test(16'd9000, 0.95681, 1.0, 0.92066);
        
        $display("--------------------------------------------------------------------");
        if (errors == 0) begin
            $display("All %0d CCT to XYZ tests PASSED.", test_num);
        end else begin
            $display("%0d out of %0d CCT to XYZ tests FAILED.", errors, test_num);
        end
        $display("Simulation completed at %0t", $time);
        $finish;
    end
    
    // Monitor XYZ validity
    always @(posedge xyz_valid_uut) begin
        $display("Info: Time %0t: XYZ conversion valid flag (xyz_valid_uut asserted)", $time);
    end

endmodule 