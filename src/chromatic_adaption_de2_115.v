module chromatic_adaption_de2_115 (
    // Clock inputs
    input wire CLOCK_50,    // 50MHz clock
    input wire CLOCK2_50,   // Secondary 50MHz clock
    
    // Reset input (active-low)
    input wire [0:0] KEY,   // KEY[0] used as reset
    
    // I2C connections for ALS sensor
    inout wire I2C_SDAT,    // I2C data line
    output wire I2C_SCLK,   // I2C clock line
    
    // User inputs
    input wire [3:0] SW,    // Slide switches
    
    // Status outputs
    output wire [7:0] LEDG, // Green LEDs
    
    // VGA outputs (placeholder for display interface)
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire VGA_CLK,
    output wire VGA_BLANK_N,
    output wire VGA_SYNC_N,
    output wire VGA_HS,
    output wire VGA_VS
);

    // Internal signals
    wire [23:0] input_rgb_data;
    wire input_valid;
    wire input_ready;
    
    wire [23:0] output_rgb_data;
    wire output_valid;
    wire output_ready;
    
    // Reset signal (active-low)
    wire rst_n = KEY[0];
    
    // Instantiate the main chromatic adaption module
    chromatic_adaption_top chromatic_adaption_inst (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .i2c_sda(I2C_SDAT),
        .i2c_scl(I2C_SCLK),
        .input_rgb_data(input_rgb_data),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .output_rgb_data(output_rgb_data),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .sw(SW),
        .led(LEDG)
    );
    
    // Test pattern generator (for demonstration)
    // In a real implementation, this would be replaced with your actual image source
    reg [23:0] test_pattern;
    reg test_valid;
    reg [31:0] pattern_counter;
    
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (~rst_n) begin
            test_pattern <= 24'hFFFFFF;  // White
            test_valid <= 1'b0;
            pattern_counter <= 32'd0;
        end else begin
            // Generate a test pattern periodically
            pattern_counter <= pattern_counter + 1;
            
            // Change pattern every ~0.5 seconds
            if (pattern_counter >= 25000000) begin
                pattern_counter <= 32'd0;
                
                // Cycle through R, G, B, White
                case (test_pattern)
                    24'hFFFFFF: test_pattern <= 24'hFF0000;  // White to Red
                    24'hFF0000: test_pattern <= 24'h00FF00;  // Red to Green
                    24'h00FF00: test_pattern <= 24'h0000FF;  // Green to Blue
                    24'h0000FF: test_pattern <= 24'hFFFFFF;  // Blue to White
                    default: test_pattern <= 24'hFFFFFF;     // Default to White
                endcase
                
                test_valid <= 1'b1;
            end else begin
                test_valid <= 1'b0;
            end
        end
    end
    
    // Connect test pattern to chromatic adaption module
    assign input_rgb_data = test_pattern;
    assign input_valid = test_valid & input_ready;
    
    // Simple VGA output (for demonstration purposes)
    // In a real application, this would be your display interface
    assign VGA_R = output_valid ? output_rgb_data[23:16] : 8'h00;
    assign VGA_G = output_valid ? output_rgb_data[15:8] : 8'h00;
    assign VGA_B = output_valid ? output_rgb_data[7:0] : 8'h00;
    
    // VGA control signals (simplified)
    assign VGA_CLK = CLOCK_50;
    assign VGA_BLANK_N = 1'b1;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_HS = 1'b1;
    assign VGA_VS = 1'b1;
    
    // Always ready to accept output from the chromatic adaption module
    assign output_ready = 1'b1;

endmodule 