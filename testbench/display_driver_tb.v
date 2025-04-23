`timescale 1ns / 1ps

module display_driver_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg [23:0] input_rgb;
    reg input_valid;
    wire [23:0] output_rgb;
    wire output_valid;
    reg output_ready;
    wire busy;
    
    // Instantiate the Unit Under Test (UUT)
    display_driver uut (
        .clk(clk),
        .rst_n(rst_n),
        .input_rgb(input_rgb),
        .input_valid(input_valid),
        .output_rgb(output_rgb),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .busy(busy)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Display RGB values
    task display_rgb;
        input [23:0] rgb;
        input reg [1023:0] label;
        begin
            $display("%s: #%06h (R=%d, G=%d, B=%d)", 
                     label, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
        end
    endtask
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("display_driver_tb.vcd");
        $dumpvars(0, display_driver_tb);
        
        // Initialize inputs
        rst_n = 0;
        input_rgb = 24'h000000;
        input_valid = 0;
        output_ready = 1;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Test case 1: Basic output with display ready
        $display("\nTest 1: Basic output, display ready");
        input_rgb = 24'hFF0000; // Red
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Check output
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Red)");
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        // Test case 2: Multiple colors
        $display("\nTest 2: Multiple colors");
        input_rgb = 24'h00FF00; // Green
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Check output
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Green)");
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        input_rgb = 24'h0000FF; // Blue
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Check output
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Blue)");
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        // Test case 3: Output with display not ready
        $display("\nTest 3: Display not ready");
        output_ready = 0;
        input_rgb = 24'hFFFF00; // Yellow
        input_valid = 1;
        #20;
        input_valid = 0;
        
        // Wait a bit, should not get output_valid
        #200;
        $display("Time %0t: Display not ready, output_valid should be 0: %b", $time, output_valid);
        
        // Now make display ready
        output_ready = 1;
        
        // Check output
        wait(output_valid);
        display_rgb(input_rgb, "Input RGB (Yellow)");
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        // Test case 4: Rapid inputs
        $display("\nTest 4: Rapid input changes");
        // Send multiple inputs rapidly
        input_rgb = 24'hFF00FF; // Magenta
        input_valid = 1;
        #20;
        
        // Change input before processing completes
        input_rgb = 24'h00FFFF; // Cyan
        #20;
        
        // Change input again
        input_rgb = 24'hFFFFFF; // White
        #20;
        input_valid = 0;
        
        // Check output (should only process the last one)
        wait(output_valid);
        display_rgb(input_rgb, "Last Input RGB (White)");
        display_rgb(output_rgb, "Output RGB");
        #100;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor busy and valid signals
    always @(posedge clk) begin
        if (busy)
            $display("Time %0t: Display driver BUSY", $time);
            
        if (output_valid)
            $display("Time %0t: Output valid", $time);
    end

endmodule 