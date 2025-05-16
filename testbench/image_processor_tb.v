`timescale 1ns / 1ps

module image_processor_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg [23:0] input_rgb;
    reg input_valid;
    wire input_ready;
    reg [287:0] comp_matrix;  // Changed to packed array format (287:0)
    reg matrix_valid;
    wire [23:0] output_rgb;
    wire output_valid;
    wire busy;
    
    // Instantiate the Unit Under Test (UUT)
    image_processor uut (
        .clk(clk),
        .rst_n(rst_n),
        .input_rgb(input_rgb),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .comp_matrix(comp_matrix),
        .matrix_valid(matrix_valid),
        .output_rgb(output_rgb),
        .output_valid(output_valid),
        .busy(busy)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Function to convert Q16.16 fixed-point to float
    function real fixed_to_float;
        input [31:0] fixed_point;
        begin
            fixed_to_float = fixed_point / 65536.0;
        end
    endfunction
    
    // Function to display RGB in hex and decimal
    task display_rgb;
        input [23:0] rgb;
        input [1023:0] label;
        begin
            $display("%s: #%06h (R=%d, G=%d, B=%d)", 
                     label, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
        end
    endtask
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("image_processor_tb.vcd");
        $dumpvars(0, image_processor_tb);
        
        // Initialize inputs
        rst_n = 0;
        input_rgb = 24'h000000;
        input_valid = 0;
        matrix_valid = 0;
        
        // Initialize the compensation matrix to identity-like matrix
        // True identity matrix for chromatic adaptation (3x3 matrix)
        // Each row corresponds to how each XYZ channel should be transformed
        comp_matrix[31:0]     = 32'h00010000; // 1.0 (0,0) - X contribution from X
        comp_matrix[63:32]    = 32'h00000000; // 0.0 (0,1) - X contribution from Y
        comp_matrix[95:64]    = 32'h00000000; // 0.0 (0,2) - X contribution from Z
        comp_matrix[127:96]   = 32'h00000000; // 0.0 (1,0) - Y contribution from X
        comp_matrix[159:128]  = 32'h00010000; // 1.0 (1,1) - Y contribution from Y
        comp_matrix[191:160]  = 32'h00000000; // 0.0 (1,2) - Y contribution from Z
        comp_matrix[223:192]  = 32'h00000000; // 0.0 (2,0) - Z contribution from X
        comp_matrix[255:224]  = 32'h00000000; // 0.0 (2,1) - Z contribution from Y
        comp_matrix[287:256]  = 32'h00010000; // 1.0 (2,2) - Z contribution from Z
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Test 1: Identity matrix, should produce same output as input
        $display("\nTest 1: Identity matrix transformation (should preserve colors)");
        matrix_valid = 1;
        #20;
        
        // Test with pure red
        wait(input_ready);
        input_rgb = 24'hFF0000; // Pure red
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Red)");
        display_rgb(output_rgb, "Output RGB (should be red)");
        #100;
        
        // Test with pure green
        wait(input_ready);
        input_rgb = 24'h00FF00; // Pure green
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Green)");
        display_rgb(output_rgb, "Output RGB (should be green)");
        #100;
        
        // Test with pure blue
        wait(input_ready);
        input_rgb = 24'h0000FF; // Pure blue
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Blue)");
        display_rgb(output_rgb, "Output RGB (should be blue)");
        #100;
        
        // Test 2: Warm-to-cool transformation (making colors cooler/more blue)
        $display("\nTest 2: Warm-to-cool compensation matrix");
        // Matrix for making colors cooler (more blue, less red/yellow)
        comp_matrix[31:0]     = 32'h0000CCCC; // 0.8 (reduce red)
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h0000E666; // 0.9 (slightly reduce green)
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h00013333; // 1.2 (boost blue)
        
        // Test with white
        wait(input_ready);
        input_rgb = 24'hFFFFFF; // White
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (White)");
        display_rgb(output_rgb, "Output RGB (should be cooler/more blue - expected: #B4C8FF)");
        if (output_rgb == 24'hB4C8FF)
            $display("✓ TEST 2 PASSED: Output matches expected cooler/blue tint (#B4C8FF)");
        else
            $display("✗ TEST 2 FAILED: Output (#%06h) does not match expected (#B4C8FF)", output_rgb);
        #100;
        
        // Test 3: Cool-to-warm transformation
        $display("\nTest 3: Cool-to-warm compensation matrix");
        // Matrix for making colors warmer (more red/yellow, less blue)
        comp_matrix[31:0]     = 32'h00013333; // 1.2 (boost red)
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h00011999; // 1.1 (slightly boost green)
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h0000CCCC; // 0.8 (reduce blue)
        
        // Test with white
        wait(input_ready);
        input_rgb = 24'hFFFFFF; // White
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (White)");
        display_rgb(output_rgb, "Output RGB (should be warmer/more red - expected: #FFBE8C)");
        if (output_rgb == 24'hFFBE8C)
            $display("✓ TEST 3 PASSED: Output matches expected warmer/red tint (#FFBE8C)");
        else
            $display("✗ TEST 3 FAILED: Output (#%06h) does not match expected (#FFBE8C)", output_rgb);
        #100;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor status changes
    reg busy_prev;
    always @(posedge clk) begin
        if (output_valid)
            $display("Time %0t: Output valid, RGB = #%06h", $time, output_rgb);
            
        if (busy && !busy_prev)
            $display("Time %0t: Image processor BUSY", $time);
            
        if (!busy && busy_prev)
            $display("Time %0t: Image processor IDLE", $time);
            
        busy_prev <= busy;
    end

endmodule 