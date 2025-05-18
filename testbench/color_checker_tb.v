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

    // Color checker array - 6x4 image (RGB values) - 24 patches
    reg [23:0] color_checker[0:23];
    reg [23:0] output_pixels[0:23];
    reg [4:0] pixel_counter;

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
            $display("Patch %2d: #%06h (R=%3d, G=%3d, B=%3d)", 
                     idx, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
            $fwrite(output_file, "Patch %2d: #%06h (R=%3d, G=%3d, B=%3d)\n", 
                    idx, rgb, rgb[23:16], rgb[15:8], rgb[7:0]);
        end
    endtask

    // Task to process a single pixel with timeout
    task process_pixel;
        input [4:0] pixel_idx;
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

        // Initialize Color Checker Classic patches
        // Row 1
        color_checker[0]  = 24'h735244; // Dark Skin (115, 82, 68)
        color_checker[1]  = 24'hC29682; // Light Skin (194, 150, 130)
        color_checker[2]  = 24'h627A9D; // Blue Sky (98, 122, 157)
        color_checker[3]  = 24'h576C43; // Foliage (87, 108, 67)
        color_checker[4]  = 24'h8580B1; // Blue Flower (133, 128, 177)
        color_checker[5]  = 24'h67BDAA; // Bluish Green (103, 189, 170)
        // Row 2
        color_checker[6]  = 24'hD67E2C; // Orange (214, 126, 44)
        color_checker[7]  = 24'h505BA6; // Purplish Blue (80, 91, 166)
        color_checker[8]  = 24'hC15A63; // Moderate Red (193, 90, 99)
        color_checker[9]  = 24'h5E3C6C; // Purple (94, 60, 108)
        color_checker[10] = 24'h9DBC40; // Yellow Green (157, 188, 64)
        color_checker[11] = 24'hE0A32E; // Orange Yellow (224, 163, 46)
        // Row 3
        color_checker[12] = 24'h383D96; // Blue (56, 61, 150)
        color_checker[13] = 24'h469449; // Green (70, 148, 73)
        color_checker[14] = 24'hAF363C; // Red (175, 54, 60)
        color_checker[15] = 24'hE7C71F; // Yellow (231, 199, 31)
        color_checker[16] = 24'hBB5695; // Magenta (187, 86, 149)
        color_checker[17] = 24'h0885A1; // Cyan (8, 133, 161)
        // Row 4
        color_checker[18] = 24'hF3F3F2; // White (243, 243, 242)
        color_checker[19] = 24'hC8C8C8; // Neutral 8 (200, 200, 200)
        color_checker[20] = 24'hA0A0A0; // Neutral 6.5 (160, 160, 160)
        color_checker[21] = 24'h7A7A79; // Neutral 5 (122, 122, 121)
        color_checker[22] = 24'h555555; // Neutral 3.5 (85, 85, 85)
        color_checker[23] = 24'h343434; // Black (52, 52, 52)

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

        $fwrite(output_file, "==== Original Color Checker Classic Values ====\n");
        for (i = 0; i < 24; i = i + 1) begin
            display_rgb(color_checker[i], i);
        end

        $fwrite(output_file, "\n==== Chromatically Adapted Values ====\n");

        // Process all pixels using the more robust method
        for (i = 0; i < 24; i = i + 1) begin
            process_pixel(i);
        end

        // Create output PPM file
        ppm_file = $fopen("color_checker_output.ppm", "w");
        $fwrite(ppm_file, "P3\n");
        $fwrite(ppm_file, "# Chromatically adapted 6x4 color checker\n");
        $fwrite(ppm_file, "6 4\n");
        $fwrite(ppm_file, "255\n");

        // Write pixel data in PPM format (6 pixels per row)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                $fwrite(ppm_file, "%d %d %d ", 
                        output_pixels[i*6+j][23:16], 
                        output_pixels[i*6+j][15:8], 
                        output_pixels[i*6+j][7:0]);
            end
            $fwrite(ppm_file, "\n");
        end

        // Also create input PPM for reference
        ppm_file = $fopen("color_checker_input.ppm", "w");
        $fwrite(ppm_file, "P3\n");
        $fwrite(ppm_file, "# Original 6x4 color checker classic\n");
        $fwrite(ppm_file, "6 4\n");
        $fwrite(ppm_file, "255\n");

        // Write original pixel data in PPM format (6 pixels per row)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                $fwrite(ppm_file, "%d %d %d ", 
                        color_checker[i*6+j][23:16], 
                        color_checker[i*6+j][15:8], 
                        color_checker[i*6+j][7:0]);
            end
            $fwrite(ppm_file, "\n");
        end

        $fclose(ppm_file);
        $fclose(output_file);
        $display("Simulation completed - output saved to color_checker_output.ppm");
        $finish;
    end

endmodule 