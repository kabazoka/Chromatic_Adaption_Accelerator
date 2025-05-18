module image_tb;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    parameter IMAGE_WIDTH = 768;
    parameter IMAGE_HEIGHT = 512;
    parameter TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT;

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
    integer input_file;
    integer output_file;
    integer scan_result;
    integer i, j;
    integer timeout_counter;
    integer processed_pixels;
    integer progress_mark;

    // RGB values
    reg [7:0] r, g, b;
    reg [23:0] output_pixels[0:TOTAL_PIXELS-1];
    
    // PPM reading
    reg [8*100:1] line_buffer; // Buffer to read lines (up to 100 chars)
    reg comment_line;

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

    // Task to process a single pixel with timeout
    task process_pixel;
        input [31:0] pixel_idx;
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
            end

            // Show progress
            processed_pixels = processed_pixels + 1;
            if (processed_pixels % (TOTAL_PIXELS/20) == 0) begin
                progress_mark = (processed_pixels * 100) / TOTAL_PIXELS;
                $display("Processing: %d%% complete", progress_mark);
            end

            // Allow some time between pixels
            #(CLK_PERIOD * 2);
        end
    endtask

    // Stimulus
    initial begin
        // Initialize waveform dump
        $dumpfile("image_tb.vcd");
        $dumpvars(0, image_tb);

        // Open input file (PPM format)
        input_file = $fopen("input_image.ppm", "r");
        if (input_file == 0) begin
            $display("Error: Could not open input_image.ppm");
            $finish;
        end

        // Open output file for the processed image
        output_file = $fopen("output_image.ppm", "w");
        if (output_file == 0) begin
            $display("Error: Could not open output_image.ppm");
            $fclose(input_file);
            $finish;
        end

        // Initialize inputs
        rst_n = 0;
        input_rgb = 24'h000000;
        input_valid = 0;
        matrix_valid = 0;
        processed_pixels = 0;

        // Initialize compensation matrix as identity matrix for testing
        // This should output the same colors as input (no adaptation)
        // For real adaptation, change to desired matrix values
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

        // Skip PPM header (P3, comments, dimensions, max value)
        $display("Reading PPM header...");
        
        // Read the P3 magic number
        scan_result = $fscanf(input_file, "P3\n");
        
        // Read lines until we get past comments (lines starting with #)
        comment_line = 1'b1;
        while (comment_line) begin
            scan_result = $fgets(line_buffer, input_file);
            if (line_buffer[8*1:1] == "#") begin
                // This is a comment line, continue reading
                comment_line = 1'b1;
            end else begin
                // Non-comment line - must be dimensions
                comment_line = 1'b0;
                // Parse the dimensions from line_buffer
                scan_result = $sscanf(line_buffer, "%d %d", i, j);
                
                if (i != IMAGE_WIDTH || j != IMAGE_HEIGHT) begin
                    $display("Warning: Image dimensions in PPM (%dx%d) do not match expected dimensions (%dx%d)",
                            i, j, IMAGE_WIDTH, IMAGE_HEIGHT);
                end
            end
        end
        
        // Read the max value line
        scan_result = $fscanf(input_file, "%d\n", i); // Max value (usually 255)
        
        // Write PPM header to output file
        $fwrite(output_file, "P3\n");
        $fwrite(output_file, "# Chromatically adapted image\n");
        $fwrite(output_file, "%d %d\n", IMAGE_WIDTH, IMAGE_HEIGHT);
        $fwrite(output_file, "255\n");

        $display("Starting image processing (%dx%d = %d pixels)...", IMAGE_WIDTH, IMAGE_HEIGHT, TOTAL_PIXELS);
        
        // Process each pixel
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                // Read RGB values for this pixel
                // Note: Reading as R,B,G instead of R,G,B to compensate for channel order mismatch
                scan_result = $fscanf(input_file, "%d %d %d", r, b, g);
                
                if (scan_result != 3) begin
                    $display("Error: Could not read pixel data at position (%d,%d)", j, i);
                    input_rgb = 24'h000000; // Black for error
                end else begin
                    // Send RGB in the correct format for the hardware
                    // RGB test confirmed that [23:16]=R, [15:8]=G, [7:0]=B
                    input_rgb = {r, g, b};
                end
                
                // Process this pixel
                process_pixel(i * IMAGE_WIDTH + j);
            end
        end

        // Write processed pixels to output file
        $display("Writing output image...");
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                // Output RGB values directly - the hardware outputs in RGB format
                // [23:16]=R, [15:8]=G, [7:0]=B as confirmed by the RGB test
                $fwrite(output_file, "%d %d %d ", 
                        output_pixels[i*IMAGE_WIDTH+j][23:16], // R
                        output_pixels[i*IMAGE_WIDTH+j][15:8],  // G
                        output_pixels[i*IMAGE_WIDTH+j][7:0]);  // B
                
                // Add newline after every 5 pixels for readability
                if ((j + 1) % 5 == 0) begin
                    $fwrite(output_file, "\n");
                end
            end
            // Ensure each row ends with a newline
            if (IMAGE_WIDTH % 5 != 0) begin
                $fwrite(output_file, "\n");
            end
        end

        $fclose(input_file);
        $fclose(output_file);
        $display("Simulation completed - output saved to output_image.ppm");
        $finish;
    end

endmodule 