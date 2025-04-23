`timescale 1ns / 1ps

module i2c_als_interface_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    wire i2c_sda;
    wire i2c_scl;
    reg read_req;
    wire [15:0] cct_out;
    wire cct_valid;
    wire busy;
    
    // Pull-up resistors for I2C
    pullup(i2c_sda);
    pullup(i2c_scl);
    
    // Instantiate the Unit Under Test (UUT)
    i2c_als_interface #(
        .CLK_FREQ(50_000_000),
        .I2C_FREQ(400_000),
        .ALS_ADDR(7'h39)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .read_req(read_req),
        .cct_out(cct_out),
        .cct_valid(cct_valid),
        .busy(busy)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Stimulus
    initial begin
        // Initialize waveform dump for GTKWave
        $dumpfile("i2c_als_interface_tb.vcd");
        $dumpvars(0, i2c_als_interface_tb);
        
        // Initialize inputs
        rst_n = 0;
        read_req = 0;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Wait for some time and then request a reading
        #200;
        $display("Time %0t: Requesting ALS reading", $time);
        read_req = 1;
        #20;
        read_req = 0;
        
        // Wait for the valid flag
        wait(cct_valid);
        $display("Time %0t: CCT reading valid, value = %d K", $time, cct_out);
        
        // Request another reading
        #10000;
        $display("Time %0t: Requesting another ALS reading", $time);
        read_req = 1;
        #20;
        read_req = 0;
        
        // Wait for the valid flag
        wait(cct_valid);
        $display("Time %0t: CCT reading valid, value = %d K", $time, cct_out);
        
        // Run for some more time
        #50000;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor
    always @(posedge clk) begin
        if (cct_valid)
            $display("Time %0t: CCT = %d K", $time, cct_out);
    end
    
    // Monitor busy status changes
    initial begin
        forever begin
            @(busy);
            if (busy)
                $display("Time %0t: ALS interface BUSY", $time);
            else
                $display("Time %0t: ALS interface IDLE", $time);
        end
    end

endmodule 