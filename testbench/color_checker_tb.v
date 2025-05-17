module color_checker_tb;

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

    // File handlers
    integer output_file;
    integer ppm_file;
    integer i, j;
    integer timeout_counter;

    // Color checker array - 4x4 image (RGB values)
    reg [23:0] color_checker[0:15];
    reg [23:0] output_pixels[0:15];
    reg [3:0] pixel_counter;

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

    // Function to display RGB in hex and decimal
    task display_rgb;
        input [23:0] rgb;
        input integer idx;
        begin
            $display("Pixel %2d: #%06h (R=%3d, G=%3d, B=%3d)", 
                     idx, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
            $fwrite(output_file, "Pixel %2d: #%06h (R=%3d, G=%3d, B=%3d)\n", 
                    idx, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
        end
    endtask

    // Task to process a single pixel with timeout
    task process_pixel;
        input [3:0] pixel_idx;
        begin
            // Try to wait for ready with timeout
            timeout_counter = 0;
            while (!input_ready && timeout_counter < 1000) begin
                #(CLK_PERIOD);
                timeout_counter = timeout_counter + 1;
            end

            if (timeout_counter >= 1000) begin
                $display("Warning: Timeout waiting for input_ready at pixel %d", pixel_idx);
            end

            // Send pixel regardless of ready signal if timed out
            input_rgb = color_checker[pixel_idx];
            input_valid = 1;
            #(CLK_PERIOD);
            input_valid = 0;

            // Wait for output with timeout
            timeout_counter = 0;
            while (!output_valid && timeout_counter < 1000) begin
                #(CLK_PERIOD);
                timeout_counter = timeout_counter + 1;
            end

            if (timeout_counter >= 1000) begin
                $display("Error: Timeout waiting for output_valid at pixel %d", pixel_idx);
                output_pixels[pixel_idx] = 24'hFF0000; // Default to red for error
            end else begin
                // Capture output
                output_pixels[pixel_idx] = output_rgb;
                display_rgb(output_rgb, pixel_idx);
            end

            // Allow some time between pixels
            #(CLK_PERIOD * 5);
        end
    endtask

    // Stimulus
    initial begin
        // Initialize waveform dump
        $dumpfile("color_checker_tb.vcd");
        $dumpvars(0, color_checker_tb);

        // Open output file
        output_file = $fopen("color_checker_output.txt", "w");

        // Initialize inputs
        rst_n = 0;
        input_rgb = 24'h000000;
        input_valid = 0;
        matrix_valid = 0;
        pixel_counter = 0;

        // Initialize 4x4 color checker
        // Row 1
        color_checker[0]  = 24'hFF0000; // Red
        color_checker[1]  = 24'h00FF00; // Green
        color_checker[2]  = 24'h0000FF; // Blue
        color_checker[3]  = 24'hFFFF00; // Yellow
        // Row 2
        color_checker[4]  = 24'h00FFFF; // Cyan
        color_checker[5]  = 24'hFF00FF; // Magenta
        color_checker[6]  = 24'h808080; // Gray
        color_checker[7]  = 24'hFFFFFF; // White
        // Row 3
        color_checker[8]  = 24'hA52A2A; // Brown
        color_checker[9]  = 24'h008000; // Dark Green
        color_checker[10] = 24'h000080; // Navy Blue
        color_checker[11] = 24'hFFA500; // Orange
        // Row 4
        color_checker[12] = 24'hFFC0CB; // Pink
        color_checker[13] = 24'h800080; // Purple
        color_checker[14] = 24'h008080; // Teal
        color_checker[15] = 24'hD2B48C; // Tan

        // Initialize compensation matrix for a cool-to-warm transformation
        // Identity matrix with slight warm tint
        comp_matrix[31:0]     = 32'h00011999; // 1.1 (boost red)
        comp_matrix[63:32]    = 32'h00000000; // 0.0
        comp_matrix[95:64]    = 32'h00000000; // 0.0
        comp_matrix[127:96]   = 32'h00000000; // 0.0
        comp_matrix[159:128]  = 32'h00010CCC; // 1.05 (slight boost green)
        comp_matrix[191:160]  = 32'h00000000; // 0.0
        comp_matrix[223:192]  = 32'h00000000; // 0.0
        comp_matrix[255:224]  = 32'h00000000; // 0.0
        comp_matrix[287:256]  = 32'h0000E666; // 0.9 (reduce blue)

        // Reset sequence
        #100;
        rst_n = 1;
        #100;

        // Set matrix valid
        matrix_valid = 1;
        #20;

        $fwrite(output_file, "==== Original Color Checker Values ====\n");
        for (i = 0; i < 16; i = i + 1) begin
            display_rgb(color_checker[i], i);
        end

        $fwrite(output_file, "\n==== Chromatically Adapted Values ====\n");

        // Process all pixels using the more robust method
        for (i = 0; i < 16; i = i + 1) begin
            process_pixel(i);
        end

        // Create output PPM file
        ppm_file = $fopen("color_checker_output.ppm", "w");
        $fwrite(ppm_file, "P3\n");
        $fwrite(ppm_file, "# Chromatically adapted 4x4 color checker\n");
        $fwrite(ppm_file, "4 4\n");
        $fwrite(ppm_file, "255\n");

        // Write pixel data in PPM format (4 pixels per row)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                $fwrite(ppm_file, "%d %d %d ", 
                        output_pixels[i*4+j][23:16], 
                        output_pixels[i*4+j][15:8], 
                        output_pixels[i*4+j][7:0]);
            end
            $fwrite(ppm_file, "\n");
        end

        // Also create input PPM for reference
        ppm_file = $fopen("color_checker_input.ppm", "w");
        $fwrite(ppm_file, "P3\n");
        $fwrite(ppm_file, "# Original 4x4 color checker\n");
        $fwrite(ppm_file, "4 4\n");
        $fwrite(ppm_file, "255\n");

        // Write original pixel data in PPM format (4 pixels per row)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                $fwrite(ppm_file, "%d %d %d ", 
                        color_checker[i*4+j][23:16], 
                        color_checker[i*4+j][15:8], 
                        color_checker[i*4+j][7:0]);
            end
            $fwrite(ppm_file, "\n");
        end

        $fclose(ppm_file);
        $fclose(output_file);
        $display("Simulation completed - output saved to color_checker_output.ppm");
        $finish;
    end

endmodule 