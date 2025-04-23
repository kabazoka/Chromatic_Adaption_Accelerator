`timescale 1ns / 1ps

module cct_to_xyz_converter_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg [15:0] cct_in;
    reg cct_valid;
    wire [31:0] xyz_out [2:0];
    wire xyz_valid;
    
    // Instantiate the Unit Under Test (UUT)
    cct_to_xyz_converter uut (
        .clk(clk),
        .rst_n(rst_n),
        .cct_in(cct_in),
        .cct_valid(cct_valid),
        .xyz_out(xyz_out),
        .xyz_valid(xyz_valid)
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
            fixed_to_float = fixed_point / 65536.0; // Q16.16 format
        end
    endtask
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("cct_to_xyz_converter_tb.vcd");
        $dumpvars(0, cct_to_xyz_converter_tb);
        
        // Initialize inputs
        rst_n = 0;
        cct_in = 0;
        cct_valid = 0;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Test with various CCT values
        // Test 1: 3000K (warm white)
        cct_in = 16'd3000;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K, XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // Test 2: 5000K (daylight)
        cct_in = 16'd5000;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K, XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // Test 3: 6500K (D65)
        cct_in = 16'd6500;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K, XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // Test 4: 8000K (cool white)
        cct_in = 16'd8000;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K, XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // Test boundary conditions
        // Test 5: Below minimum (should clamp to 3000K)
        cct_in = 16'd2500;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K (should clamp to 3000K), XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // Test 6: Above maximum (should clamp to 8000K)
        cct_in = 16'd9000;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Wait for conversion
        wait(xyz_valid);
        $display("Time %0t: CCT = %d K (should clamp to 8000K), XYZ = (%f, %f, %f)", 
                 $time, cct_in, 
                 fixed_to_float(xyz_out[0]), 
                 fixed_to_float(xyz_out[1]), 
                 fixed_to_float(xyz_out[2]));
        #100;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor XYZ validity
    always @(posedge xyz_valid) begin
        $display("Time %0t: XYZ conversion valid", $time);
    end

endmodule 