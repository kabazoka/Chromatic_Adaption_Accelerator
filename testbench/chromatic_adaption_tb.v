`timescale 1ns / 1ps

module chromatic_adaption_tb;

    // Clock and reset signals
    reg clk;
    reg rst_n;
    
    // I2C interface
    wire i2c_sda;
    wire i2c_scl;
    
    // Image input/output
    reg [23:0] input_rgb_data;
    reg input_valid;
    wire input_ready;
    
    wire [23:0] output_rgb_data;
    wire output_valid;
    reg output_ready;
    
    // Control signals
    reg [3:0] sw;
    wire [7:0] led;
    
    // Instantiate the DUT
    chromatic_adaption_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .input_rgb_data(input_rgb_data),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .output_rgb_data(output_rgb_data),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .sw(sw),
        .led(led)
    );
    
    // Pull-up resistors for I2C
    pullup(i2c_sda);
    pullup(i2c_scl);
    
    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50MHz clock
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        input_rgb_data = 24'h000000;
        input_valid = 0;
        output_ready = 1;
        sw = 4'b0000;
        
        // Release reset
        #100;
        rst_n = 1;
        #100;
        
        // Wait for the ALS reading and conversion to complete
        // (The simulated ALS in the i2c_als_interface will return data)
        #500000;
        
        // Input a test image pixel (red)
        input_rgb_data = 24'hFF0000;
        input_valid = 1;
        
        // Wait for the system to process the pixel
        wait(input_ready);
        input_valid = 0;
        
        // Wait for the output
        wait(output_valid);
        $display("Input RGB: %h", 24'hFF0000);
        $display("Output RGB: %h", output_rgb_data);
        
        // Input another test pixel (green)
        #100;
        input_rgb_data = 24'h00FF00;
        input_valid = 1;
        
        // Wait for the system to process the pixel
        wait(input_ready);
        input_valid = 0;
        
        // Wait for the output
        wait(output_valid);
        $display("Input RGB: %h", 24'h00FF00);
        $display("Output RGB: %h", output_rgb_data);
        
        // Input another test pixel (blue)
        #100;
        input_rgb_data = 24'h0000FF;
        input_valid = 1;
        
        // Wait for the system to process the pixel
        wait(input_ready);
        input_valid = 0;
        
        // Wait for the output
        wait(output_valid);
        $display("Input RGB: %h", 24'h0000FF);
        $display("Output RGB: %h", output_rgb_data);
        
        // Continue simulation for a while to observe LED status
        #100000;
        
        // End simulation
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor system status
    always @(led) begin
        $display("Time: %t, LED Status: %b", $time, led);
    end

endmodule 