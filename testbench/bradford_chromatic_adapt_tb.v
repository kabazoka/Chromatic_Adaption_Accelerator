`timescale 1ns / 1ps

module bradford_chromatic_adapt_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg [(2-0)*(31-0+1)+(31-0):0] ambient_xyz;
    reg xyz_valid;
    reg [15:0] ref_cct;
    wire [31:0] comp_matrix [8:0];
    wire matrix_valid;
    
    // Instantiate the Unit Under Test (UUT)
    bradford_chromatic_adapt uut (
        .clk(clk),
        .rst_n(rst_n),
        .ambient_xyz(ambient_xyz),
        .xyz_valid(xyz_valid),
        .ref_cct(ref_cct),
        .comp_matrix(comp_matrix),
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
            // Convert Q16.16 to float
            fixed_to_float = fixed_point / 65536.0;
        end
    endfunction
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("bradford_chromatic_adapt_tb.vcd");
        $dumpvars(0, bradford_chromatic_adapt_tb);
        
        // Initialize inputs
        rst_n = 0;
        ambient_xyz[0] = 0;
        ambient_xyz[1] = 0;
        ambient_xyz[2] = 0;
        xyz_valid = 0;
        ref_cct = 16'd6500; // D65 reference
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Test case 1: 5000K ambient light (close to daylight)
        // XYZ values for 5000K, converted from CCT
        ambient_xyz[0] = 32'h00013333; // ~1.2 in Q16.16
        ambient_xyz[1] = 32'h00010000; // 1.0 in Q16.16
        ambient_xyz[2] = 32'h0000B333; // ~0.7 in Q16.16
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        
        // Wait for matrix calculation
        wait(matrix_valid);
        $display("Time %0t: Compensation matrix for 5000K to 6500K:", $time);
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[0]), 
                 fixed_to_float(comp_matrix[1]), 
                 fixed_to_float(comp_matrix[2]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[3]), 
                 fixed_to_float(comp_matrix[4]), 
                 fixed_to_float(comp_matrix[5]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[6]), 
                 fixed_to_float(comp_matrix[7]), 
                 fixed_to_float(comp_matrix[8]));
        #100;
        
        // Test case 2: 3000K ambient light (warm/tungsten)
        // XYZ values for 3000K, converted from CCT
        ambient_xyz[0] = 32'h00017AE1; // ~1.48 in Q16.16
        ambient_xyz[1] = 32'h00010000; // 1.0 in Q16.16
        ambient_xyz[2] = 32'h00005C29; // ~0.36 in Q16.16
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        
        // Wait for matrix calculation
        wait(matrix_valid);
        $display("Time %0t: Compensation matrix for 3000K to 6500K:", $time);
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[0]), 
                 fixed_to_float(comp_matrix[1]), 
                 fixed_to_float(comp_matrix[2]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[3]), 
                 fixed_to_float(comp_matrix[4]), 
                 fixed_to_float(comp_matrix[5]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[6]), 
                 fixed_to_float(comp_matrix[7]), 
                 fixed_to_float(comp_matrix[8]));
        #100;
        
        // Test case 3: 8000K ambient light (cool/bluish)
        // XYZ values for 8000K, converted from CCT
        ambient_xyz[0] = 32'h0000C000; // ~0.75 in Q16.16
        ambient_xyz[1] = 32'h00010000; // 1.0 in Q16.16
        ambient_xyz[2] = 32'h00016000; // ~1.375 in Q16.16
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        
        // Wait for matrix calculation
        wait(matrix_valid);
        $display("Time %0t: Compensation matrix for 8000K to 6500K:", $time);
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[0]), 
                 fixed_to_float(comp_matrix[1]), 
                 fixed_to_float(comp_matrix[2]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[3]), 
                 fixed_to_float(comp_matrix[4]), 
                 fixed_to_float(comp_matrix[5]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[6]), 
                 fixed_to_float(comp_matrix[7]), 
                 fixed_to_float(comp_matrix[8]));
        #100;
        
        // Test case 4: D65 (6500K) as ambient - should be identity-like matrix
        ambient_xyz[0] = 32'h0000F852; // 0.95047 in Q16.16
        ambient_xyz[1] = 32'h00010000; // 1.0 in Q16.16
        ambient_xyz[2] = 32'h00010721; // 1.08883 in Q16.16
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        
        // Wait for matrix calculation
        wait(matrix_valid);
        $display("Time %0t: Compensation matrix for 6500K to 6500K (should be close to identity):", $time);
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[0]), 
                 fixed_to_float(comp_matrix[1]), 
                 fixed_to_float(comp_matrix[2]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[3]), 
                 fixed_to_float(comp_matrix[4]), 
                 fixed_to_float(comp_matrix[5]));
        $display("  [%f, %f, %f]", 
                 fixed_to_float(comp_matrix[6]), 
                 fixed_to_float(comp_matrix[7]), 
                 fixed_to_float(comp_matrix[8]));
        #100;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor matrix validity
    always @(posedge matrix_valid) begin
        $display("Time %0t: Compensation matrix calculation complete", $time);
    end

endmodule 