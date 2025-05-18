module rgb_ordering_test;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    
    // Signals
    reg clk;
    reg rst_n;
    reg [23:0] input_rgb;
    reg input_valid;
    wire input_ready;
    reg [287:0] comp_matrix;
    reg matrix_valid;
    wire [23:0] output_rgb;
    wire output_valid;
    wire busy;
    
    // Test variables
    integer output_file;
    integer i;
    integer timeout_counter;
    
    // Define test colors with known RGB values
    reg [23:0] test_colors[0:5];
    reg [23:0] output_colors[0:5];
    
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
    
    // Task to process a single color with timeout
    task process_color;
        input [2:0] color_idx;
        begin
            // Try to wait for ready with timeout
            timeout_counter = 0;
            while (!input_ready && timeout_counter < 1000) begin
                #(CLK_PERIOD);
                timeout_counter = timeout_counter + 1;
            end
            
            if (timeout_counter >= 1000) begin
                $display("Warning: Timeout waiting for input_ready at color %d", color_idx);
            end
            
            // Send color
            input_rgb = test_colors[color_idx];
            input_valid = 1;
            $display("Processing color %d: R=%d, G=%d, B=%d (0x%h)",
                      color_idx, 
                      input_rgb[23:16], 
                      input_rgb[15:8], 
                      input_rgb[7:0],
                      input_rgb);
            #(CLK_PERIOD);
            input_valid = 0;
            
            // Wait for output with timeout
            timeout_counter = 0;
            while (!output_valid && timeout_counter < 1000) begin
                #(CLK_PERIOD);
                timeout_counter = timeout_counter + 1;
            end
            
            if (timeout_counter >= 1000) begin
                $display("Error: Timeout waiting for output_valid at color %d", color_idx);
                output_colors[color_idx] = 24'hFF0000; // Red for error
            end else begin
                // Capture output
                output_colors[color_idx] = output_rgb;
                $display("Output color %d: R=%d, G=%d, B=%d (0x%h)", 
                          color_idx,
                          output_rgb[23:16], 
                          output_rgb[15:8], 
                          output_rgb[7:0],
                          output_rgb);
            end
            
            // Allow some time between colors
            #(CLK_PERIOD * 5);
        end
    endtask
    
    // Stimulus and test
    initial begin
        // Open output file
        output_file = $fopen("rgb_ordering_test.txt", "w");
        
        // Initialize inputs
        rst_n = 0;
        input_rgb = 24'h000000;
        input_valid = 0;
        matrix_valid = 0;
        
        // Initialize test colors
        // Pure Red, Green, Blue, Yellow, Cyan, Magenta
        test_colors[0] = 24'hFF0000; // Pure Red
        test_colors[1] = 24'h00FF00; // Pure Green
        test_colors[2] = 24'h0000FF; // Pure Blue
        test_colors[3] = 24'hFFFF00; // Yellow (Red+Green)
        test_colors[4] = 24'h00FFFF; // Cyan (Green+Blue)
        test_colors[5] = 24'hFF00FF; // Magenta (Red+Blue)
        
        // Initialize identity matrix
        comp_matrix[31:0]     = 32'h00010000; // 1.0
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h00010000; // 1.0
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h00010000; // 1.0
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        // Set matrix valid
        matrix_valid = 1;
        #20;
        
        $display("Starting RGB ordering test...");
        $fwrite(output_file, "RGB Ordering Test Results\n");
        $fwrite(output_file, "=======================\n\n");
        
        // Process each test color
        for (i = 0; i < 6; i = i + 1) begin
            process_color(i);
            
            // Write color information to output file
            $fwrite(output_file, "Color %d:\n", i);
            $fwrite(output_file, "  Input:  R=%3d, G=%3d, B=%3d (0x%06h)\n", 
                    test_colors[i][23:16], test_colors[i][15:8], test_colors[i][7:0], test_colors[i]);
            $fwrite(output_file, "  Output: R=%3d, G=%3d, B=%3d (0x%06h)\n\n", 
                    output_colors[i][23:16], output_colors[i][15:8], output_colors[i][7:0], output_colors[i]);
        end
        
        // Analyze channel mapping
        $fwrite(output_file, "Channel Mapping Analysis\n");
        $fwrite(output_file, "======================\n\n");
        
        // Red test
        $fwrite(output_file, "Red Test (0xFF0000):\n");
        $fwrite(output_file, "  Input bits  [23:16]=[15:8]=[7:0]: 255,0,0\n");
        $fwrite(output_file, "  Output bits [23:16]=[15:8]=[7:0]: %d,%d,%d\n\n", 
                output_colors[0][23:16], output_colors[0][15:8], output_colors[0][7:0]);
        
        // Green test
        $fwrite(output_file, "Green Test (0x00FF00):\n");
        $fwrite(output_file, "  Input bits  [23:16]=[15:8]=[7:0]: 0,255,0\n");
        $fwrite(output_file, "  Output bits [23:16]=[15:8]=[7:0]: %d,%d,%d\n\n", 
                output_colors[1][23:16], output_colors[1][15:8], output_colors[1][7:0]);
        
        // Blue test
        $fwrite(output_file, "Blue Test (0x0000FF):\n");
        $fwrite(output_file, "  Input bits  [23:16]=[15:8]=[7:0]: 0,0,255\n");
        $fwrite(output_file, "  Output bits [23:16]=[15:8]=[7:0]: %d,%d,%d\n\n", 
                output_colors[2][23:16], output_colors[2][15:8], output_colors[2][7:0]);
        
        // Channel interpretation
        $fwrite(output_file, "Interpretation of Mappings:\n");
        
        // Check if channels are reversed (BGR)
        if (output_colors[2][23:16] > 200 && output_colors[1][15:8] > 200 && output_colors[0][7:0] > 200) begin
            $fwrite(output_file, "  Channel ordering appears to be: BGR\n");
            $fwrite(output_file, "  [23:16]=Blue, [15:8]=Green, [7:0]=Red\n");
        end
        // Check if RGB ordering is preserved
        else if (output_colors[0][23:16] > 200 && output_colors[1][15:8] > 200 && output_colors[2][7:0] > 200) begin
            $fwrite(output_file, "  Channel ordering appears to be: RGB\n");
            $fwrite(output_file, "  [23:16]=Red, [15:8]=Green, [7:0]=Blue\n");
        end
        else begin
            $fwrite(output_file, "  Channel ordering is unclear or mixed\n");
        end
        
        $fclose(output_file);
        $display("RGB ordering test completed. Results saved to rgb_ordering_test.txt");
        $finish;
    end

endmodule 