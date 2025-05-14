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
        // Identity matrix in Q16.16 fixed-point format
        comp_matrix[31:0]     = 32'h00010000; // 1.0 (00)
        comp_matrix[63:32]    = 32'h00000000; // 0.0 (01)
        comp_matrix[95:64]    = 32'h00000000; // 0.0 (02)
        comp_matrix[127:96]   = 32'h00000000; // 0.0 (10)
        comp_matrix[159:128]  = 32'h00010000; // 1.0 (11)
        comp_matrix[191:160]  = 32'h00000000; // 0.0 (12)
        comp_matrix[223:192]  = 32'h00000000; // 0.0 (20)
        comp_matrix[255:224]  = 32'h00000000; // 0.0 (21)
        comp_matrix[287:256]  = 32'h00010000; // 1.0 (22)
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Test 1: Identity matrix, should produce same output as input
        matrix_valid = 1;
        #20;
        
        // Test with pure red
        $display("\nTest 1: Identity matrix transformation");
        wait(input_ready);
        input_rgb = 24'hFF0000; // Pure red
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Red)");
        display_rgb(output_rgb, "Output RGB");
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
        display_rgb(output_rgb, "Output RGB");
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
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        // Test 2: Non-identity transformation (simulating warm to cool light)
        $display("\nTest 2: Warm-to-cool compensation matrix");
        // This matrix would make the image cooler (more blue)
        comp_matrix[31:0]     = 32'h0000C000; // 0.75 (reduce red)
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h0000E000; // 0.875 (slightly reduce green)
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h00014000; // 1.25 (increase blue)
        
        // Test with white
        wait(input_ready);
        input_rgb = 24'hFFFFFF; // White
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (White)");
        display_rgb(output_rgb, "Output RGB (should be cooler/more blue)");
        #100;
        
        // Test 3: Cool-to-warm transformation
        $display("\nTest 3: Cool-to-warm compensation matrix");
        // This matrix would make the image warmer (more red/yellow)
        comp_matrix[31:0]     = 32'h00014000; // 1.25 (increase red)
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h00011000; // 1.0625 (slightly increase green)
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h0000C000; // 0.75 (reduce blue)
        
        // Test with white
        wait(input_ready);
        input_rgb = 24'hFFFFFF; // White
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait for processing to complete
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (White)");
        display_rgb(output_rgb, "Output RGB (should be warmer/more red)");
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