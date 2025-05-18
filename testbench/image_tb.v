// -----------------------------------------------------------------------------
//  Test-bench : apply Bradford chromatic-adaptation to a fixed PPM image
//  修正項目：
//    1. ambient_xyz 直接用 D65 (Q16.16) 常數；十六進位正確化
//    2. compensation-matrix / 像素列印一律加 $signed()，避免 65535.xx 假象
//    3. fallback 矩陣也宣告為 signed 常數
// -----------------------------------------------------------------------------
module image_tb;

    // -----------------------------------------------------------------
    // parameters
    // -----------------------------------------------------------------
    parameter CLK_PERIOD    = 20;
    parameter IMAGE_WIDTH   = 768;
    parameter IMAGE_HEIGHT  = 512;
    localparam TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT;

    parameter CCT_VALUE     = 6500;

    // -----------------------------------------------------------------
    // clocks / resets
    // -----------------------------------------------------------------
    reg clk  = 0;
    reg rst_n= 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -----------------------------------------------------------------
    // I/O with DUT
    // -----------------------------------------------------------------
    reg  [23:0] input_rgb;
    reg         input_valid;
    wire        input_ready;
    reg  [287:0] comp_matrix;
    reg         matrix_valid;
    wire [23:0] output_rgb;
    wire        output_valid;
    wire        busy;

    // -----------------------------------------------------------------
    // Bradford adaptor I/O
    // -----------------------------------------------------------------
    reg  signed [95:0] ambient_xyz;      // *** FIX : signed
    reg         xyz_valid;
    reg  [15:0] ref_cct;
    wire [287:0] bradford_matrix;
    wire        bradford_matrix_valid;

    // -----------------------------------------------------------------
    // file handles / misc
    // -----------------------------------------------------------------
    integer input_file , output_file , scan_result;
    integer ppm_w , ppm_h , maxv;
    integer x , y , timeout_counter , processed_pixels;
    integer c;  // For character reading
    reg [8*100:1] dummy_str; // 100 character buffer for $fgets

    // pixel buffers
    reg  [7:0] r, g, b;
    reg  [23:0] out_pix [0:TOTAL_PIXELS-1];

    // -----------------------------------------------------------------
    // DUT instances
    // -----------------------------------------------------------------
    bradford_chromatic_adapt bradford (
        .clk(clk), .rst_n(rst_n),
        .ambient_xyz(ambient_xyz),
        .xyz_valid(xyz_valid),
        .ref_cct(ref_cct),
        .comp_matrix(bradford_matrix),
        .matrix_valid(bradford_matrix_valid)
    );

    image_processor dut (
        .clk(clk), .rst_n(rst_n),
        .input_rgb(input_rgb),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .comp_matrix(comp_matrix),
        .matrix_valid(matrix_valid),
        .output_rgb(output_rgb),
        .output_valid(output_valid),
        .busy(busy)
    );

    // -----------------------------------------------------------------
    // helpers
    // -----------------------------------------------------------------
    task automatic wait_ready;
        begin
            timeout_counter = 0;
            while (!input_ready && timeout_counter < 1000) begin
                #(CLK_PERIOD); timeout_counter = timeout_counter + 1;
            end
        end
    endtask

    task automatic wait_output;
        input integer idx;
        begin
            timeout_counter = 0;
            while (!output_valid && timeout_counter < 1000) begin
                #(CLK_PERIOD); timeout_counter = timeout_counter + 1;
            end
            if (timeout_counter >= 1000) begin
                $display("! timeout @pixel %0d", idx);
                out_pix[idx] = 24'hFF0000;
            end
            else out_pix[idx] = output_rgb;
        end
    endtask

    // -----------------------------------------------------------------
    // stimulus
    // -----------------------------------------------------------------
    initial begin
        // waveform
        $dumpfile("image_tb.vcd"); $dumpvars(0,image_tb);

        // -----------------------------------------------------------------
        // open PPM
        // -----------------------------------------------------------------
        input_file = $fopen("input_image.ppm", "r");
        if (!input_file) begin
            $fatal("Cannot open input_image.ppm");
        end
        output_file= $fopen("output_image.ppm", "w");
        if (!output_file) begin
            $fatal("Cannot open output_image.ppm");
        end

        // -----------------------------------------------------------------
        // init signals
        // -----------------------------------------------------------------
        input_rgb    = 0; input_valid = 0; matrix_valid = 0;
        processed_pixels = 0;

        // *** FIX : 正確 D65 (0.95047 , 1.000 , 1.08883) × 65536
        ambient_xyz[31:0]  = 32'h0000F3F2;   // 0.95047
        ambient_xyz[63:32] = 32'h00010000;   // 1.0
        ambient_xyz[95:64] = 32'h000116CB;   // 1.08883
        xyz_valid = 0;
        ref_cct   = CCT_VALUE;

        // reset
        #(5*CLK_PERIOD); rst_n = 1; #(5*CLK_PERIOD);

        // -----------------------------------------------------------------
        // get Bradford matrix
        // -----------------------------------------------------------------
        xyz_valid = 1; #(CLK_PERIOD); xyz_valid = 0;
        timeout_counter = 0;
        while (!bradford_matrix_valid && timeout_counter < 2000) begin
            #(CLK_PERIOD); timeout_counter = timeout_counter + 1;
        end
        if (!bradford_matrix_valid) $fatal("Bradford adaptor timeout");

        comp_matrix   = bradford_matrix;
        matrix_valid  = 1;                // inform image_processor

        $display(">> Bradford matrix ready");

        // -----------------------------------------------------------------
        // print matrix (signed)
        // -----------------------------------------------------------------
        $display("[%f %f %f]",
                 $itor($signed(comp_matrix[ 31:  0]))/65536.0,
                 $itor($signed(comp_matrix[ 63: 32]))/65536.0,
                 $itor($signed(comp_matrix[ 95: 64]))/65536.0);
        $display("[%f %f %f]",
                 $itor($signed(comp_matrix[127: 96]))/65536.0,
                 $itor($signed(comp_matrix[159:128]))/65536.0,
                 $itor($signed(comp_matrix[191:160]))/65536.0);
        $display("[%f %f %f]",
                 $itor($signed(comp_matrix[223:192]))/65536.0,
                 $itor($signed(comp_matrix[255:224]))/65536.0,
                 $itor($signed(comp_matrix[287:256]))/65536.0);

        // -----------------------------------------------------------------
        // read PPM header - direct approach
        // -----------------------------------------------------------------
        // Read PPM header directly
        // First line: P3
        scan_result = $fgetc(input_file); // P
        scan_result = $fgetc(input_file); // 3
        scan_result = $fgetc(input_file); // newline
        
        // Comment line (skip it)
        scan_result = $fgetc(input_file);
        while (scan_result != "\n") begin
            scan_result = $fgetc(input_file);
        end
        
        // Dimensions
        scan_result = $fscanf(input_file, "%d %d", ppm_w, ppm_h);
        
        // Max value
        scan_result = $fscanf(input_file, "%d", maxv);

        if (ppm_w!=IMAGE_WIDTH || ppm_h!=IMAGE_HEIGHT)
            $display("!! PPM size %0dx%0d != expected %0dx%0d",ppm_w,ppm_h,
                     IMAGE_WIDTH,IMAGE_HEIGHT);

        // write header to output
        $fwrite(output_file,"P3\n");
        $fwrite(output_file,"# chromatically-adapted, CCT=%0dK\n",CCT_VALUE);
        $fwrite(output_file,"%0d %0d\n", IMAGE_WIDTH, IMAGE_HEIGHT);
        $fwrite(output_file,"255\n");

        // -----------------------------------------------------------------
        // main pixel loop
        // -----------------------------------------------------------------
        $display(">> processing %0d pixels …", TOTAL_PIXELS);
        for (y=0; y<IMAGE_HEIGHT; y=y+1) begin
            for (x=0; x<IMAGE_WIDTH; x=x+1) begin
                if ($fscanf(input_file,"%d %d %d", r, g, b)!=3)
                    $fatal("read error @(%0d,%0d)",x,y);

                input_rgb   = {r[7:0], g[7:0], b[7:0]}; // R,G,B order
                wait_ready();
                input_valid = 1; #(CLK_PERIOD);
                input_valid = 0;
                wait_output(y*IMAGE_WIDTH+x);

                // write to PPM on the fly (降低記憶體)
                $fwrite(output_file,"%0d %0d %0d ",
                        out_pix[y*IMAGE_WIDTH+x][23:16],
                        out_pix[y*IMAGE_WIDTH+x][15:8 ],
                        out_pix[y*IMAGE_WIDTH+x][7:0 ]);
            end
            $fwrite(output_file,"\n");
            if (y % 32 == 31) $display("   line %0d / %0d done", y+1, IMAGE_HEIGHT);
        end

        // -----------------------------------------------------------------
        // done
        // -----------------------------------------------------------------
        $display(">> finished, saved to output_image.ppm");
        $fclose(input_file); $fclose(output_file);
        $finish;
    end
endmodule
