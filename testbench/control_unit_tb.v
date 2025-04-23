`timescale 1ns / 1ps

module control_unit_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg als_busy;
    reg processing_busy;
    reg display_busy;
    reg cct_valid;
    reg xyz_valid;
    reg matrix_valid;
    reg [3:0] sw;
    wire als_read_req;
    wire [7:0] leds;
    
    // Instantiate the Unit Under Test (UUT)
    control_unit uut (
        .clk(clk),
        .rst_n(rst_n),
        .als_busy(als_busy),
        .processing_busy(processing_busy),
        .display_busy(display_busy),
        .cct_valid(cct_valid),
        .xyz_valid(xyz_valid),
        .matrix_valid(matrix_valid),
        .sw(sw),
        .als_read_req(als_read_req),
        .leds(leds)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper to display LED status
    task display_leds;
        begin
            $display("LEDs = %b", leds);
            $display("  ALS Busy:      %b", leds[7]);
            $display("  CCT Valid:     %b", leds[6]);
            $display("  XYZ Valid:     %b", leds[5]);
            $display("  Matrix Valid:  %b", leds[4]);
            $display("  Processing:    %b", leds[3]);
            $display("  Display:       %b", leds[2]);
            $display("  State:         %b", leds[1:0]);
        end
    endtask
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("control_unit_tb.vcd");
        $dumpvars(0, control_unit_tb);
        
        // Initialize inputs
        rst_n = 0;
        als_busy = 0;
        processing_busy = 0;
        display_busy = 0;
        cct_valid = 0;
        xyz_valid = 0;
        matrix_valid = 0;
        sw = 4'b0000;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // After reset, the control unit should be in INIT state
        $display("Time %0t: After reset", $time);
        display_leds();
        #100;
        
        // The control unit should request ALS reading soon
        wait(als_read_req);
        $display("Time %0t: ALS read request detected", $time);
        
        // Simulate ALS becoming busy
        als_busy = 1;
        #50;
        
        // Display LED status
        $display("Time %0t: ALS busy", $time);
        display_leds();
        
        // Simulate ALS finishing and providing CCT
        #200;
        als_busy = 0;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        
        // Display LED status
        $display("Time %0t: CCT valid", $time);
        display_leds();
        
        // Simulate XYZ conversion
        #100;
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        
        // Display LED status
        $display("Time %0t: XYZ valid", $time);
        display_leds();
        
        // Simulate matrix calculation
        #100;
        matrix_valid = 1;
        #20;
        
        // Display LED status
        $display("Time %0t: Matrix valid", $time);
        display_leds();
        
        // Simulate image processing
        processing_busy = 1;
        #200;
        processing_busy = 0;
        
        // Display LED status
        $display("Time %0t: Processing done", $time);
        display_leds();
        
        // Simulate display update
        display_busy = 1;
        #150;
        display_busy = 0;
        
        // Display LED status
        $display("Time %0t: Display update done", $time);
        display_leds();
        
        // Wait for next ALS read request
        // We'll reduce the wait time for simulation
        uut.delay_counter = 24'd1000;
        
        wait(als_read_req);
        $display("Time %0t: Next ALS read request detected", $time);
        
        // Run one more cycle
        als_busy = 1;
        #50;
        als_busy = 0;
        cct_valid = 1;
        #20;
        cct_valid = 0;
        #100;
        xyz_valid = 1;
        #20;
        xyz_valid = 0;
        #100;
        matrix_valid = 1;
        #20;
        #100;
        processing_busy = 1;
        #200;
        processing_busy = 0;
        #100;
        display_busy = 1;
        #150;
        display_busy = 0;
        
        // Final LED status
        $display("Time %0t: Final state", $time);
        display_leds();
        
        // End simulation
        #500;
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor LED changes
    initial begin
        forever begin
            @(leds);
            $display("Time %0t: LEDs changed", $time);
        end
    end
    
    // Monitor als_read_req
    always @(posedge als_read_req) begin
        $display("Time %0t: ALS read request asserted", $time);
    end

endmodule 