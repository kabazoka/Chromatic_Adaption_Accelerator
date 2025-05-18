/* -----------------------------------------------------------------------------
 *  Image Processor with Bradford Chromatic Adaptation (fixed‑point Q16.16)
 *  (SECOND FIX – adds proper clamping and cleans up missing semicolons)
 * ---------------------------------------------------------------------------*/

module image_processor (
    input  wire          clk,
    input  wire          rst_n,

    // ---------------- input stream ----------------
    input  wire  [23:0]  input_rgb,      // sRGB, 8‑bit / channel
    input  wire          input_valid,
    output reg           input_ready,

    // 3×3 Bradford compensation matrix, flattened row‑major
    input  wire [287:0]  comp_matrix,
    input  wire          matrix_valid,

    // ---------------- output stream ---------------
    output reg  [23:0]   output_rgb,     // sRGB, 8‑bit / channel
    output reg           output_valid,

    // ---------------- status ----------------------
    output reg           busy
);

    /* ------------------------------------------------------------------
     *  Fixed‑point settings (Q16.16)
     * ----------------------------------------------------------------*/
    localparam FRAC_BITS = 16;
    localparam FP_ONE    = 32'h0001_0000;   // 1.0 in Q16.16

    /* ---------------- state machine ---------------- */
    localparam IDLE       = 3'd0,
               RGB_TO_XYZ = 3'd1,
               APPLY_COMP = 3'd2,
               XYZ_TO_RGB = 3'd3,
               OUTPUT     = 3'd4;

    /* ---------------- sRGB ↔ XYZ matrices (D65) ---- */
    // sRGB → XYZ (signed Q16.16)
    localparam signed [31:0] M_RGB_TO_XYZ_00 = 32'h0000_6996,
                             M_RGB_TO_XYZ_01 = 32'h0000_3556,
                             M_RGB_TO_XYZ_02 = 32'h0000_1D96,
                             M_RGB_TO_XYZ_10 = 32'h0000_3A3C,
                             M_RGB_TO_XYZ_11 = 32'h0000_7333,
                             M_RGB_TO_XYZ_12 = 32'h0000_1E18,
                             M_RGB_TO_XYZ_20 = 32'h0000_026F,
                             M_RGB_TO_XYZ_21 = 32'h0000_076C,
                             M_RGB_TO_XYZ_22 = 32'h0000_F333;

    // XYZ → sRGB (signed Q16.16)
    localparam signed [31:0] M_XYZ_TO_RGB_00 = 32'h0003_2F5C,
                             M_XYZ_TO_RGB_01 = 32'hFFFF_0BE0,
                             M_XYZ_TO_RGB_02 = 32'hFFFF_D3F6,
                             M_XYZ_TO_RGB_10 = 32'hFFFF_9456,
                             M_XYZ_TO_RGB_11 = 32'h0001_E148,
                             M_XYZ_TO_RGB_12 = 32'h0000_0556,
                             M_XYZ_TO_RGB_20 = 32'h0000_0E55,
                             M_XYZ_TO_RGB_21 = 32'hFFFF_A4CD,
                             M_XYZ_TO_RGB_22 = 32'h0001_0E22;

    /* ---------------- internal regs / wires -------- */
    reg  [2:0] state;

    // byte‑wide I/O
    reg  [7:0] r_in, g_in, b_in;
    reg  [7:0] r_out, g_out, b_out;

    // 3‑vectors (packed signed Q16.16)
    reg signed [95:0] rgb_linear;
    reg signed [95:0] xyz_values;
    reg signed [95:0] xyz_adapted;
    reg signed [95:0] rgb_linear_out;

    // Unpack compensation matrix (signed Q16.16)
    wire signed [31:0] comp00 = comp_matrix[ 31:  0];
    wire signed [31:0] comp01 = comp_matrix[ 63: 32];
    wire signed [31:0] comp02 = comp_matrix[ 95: 64];
    wire signed [31:0] comp10 = comp_matrix[127: 96];
    wire signed [31:0] comp11 = comp_matrix[159:128];
    wire signed [31:0] comp12 = comp_matrix[191:160];
    wire signed [31:0] comp20 = comp_matrix[223:192];
    wire signed [31:0] comp21 = comp_matrix[255:224];
    wire signed [31:0] comp22 = comp_matrix[287:256];

    /* ==================================================================
     *  Fixed‑point primitives
     * =================================================================*/

    // signed 32×32 multiply → Q16.16 (keep high 32)
    function automatic [31:0] fp_multiply;
        input signed [31:0] a, b;
        reg   signed [63:0] p;
        begin
            p            = a * b;          // Q32.32
            fp_multiply  = p >>> FRAC_BITS; // back to Q16.16
        end
    endfunction

    // signed division a / b (Q16.16)
    function automatic [31:0] fp_divide;
        input signed [31:0] a, b;
        reg   signed [63:0] tmp;
        begin
            if (b == 0)       fp_divide = 32'h7FFF_FFFF;  // saturate
            else begin
                tmp = (a <<< FRAC_BITS) / b;
                fp_divide = (tmp > 32'h7FFF_FFFF) ? 32'h7FFF_FFFF : tmp[31:0];
            end
        end
    endfunction

    // clamp negatives to 0 (keeps Q16.16)
    function automatic [31:0] clamp_pos;
        input signed [31:0] v;
        begin
            clamp_pos = v[31] ? 32'sd0 : v;
        end
    endfunction

    /* ==================================================================
     *  Color‑space helpers – all use 64‑bit accum to stop overflow
     * =================================================================*/

    task automatic rgb_to_xyz;
        reg signed [63:0] acc;
        begin
            // X
            acc = $signed(fp_multiply(M_RGB_TO_XYZ_00, rgb_linear[31:0])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_01, rgb_linear[63:32])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_02, rgb_linear[95:64]));
            xyz_values[31:0] = clamp_pos(acc[31:0]);

            // Y
            acc = $signed(fp_multiply(M_RGB_TO_XYZ_10, rgb_linear[31:0])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_11, rgb_linear[63:32])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_12, rgb_linear[95:64]));
            xyz_values[63:32] = clamp_pos(acc[31:0]);

            // Z
            acc = $signed(fp_multiply(M_RGB_TO_XYZ_20, rgb_linear[31:0])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_21, rgb_linear[63:32])) +
                  $signed(fp_multiply(M_RGB_TO_XYZ_22, rgb_linear[95:64]));
            xyz_values[95:64] = clamp_pos(acc[31:0]);
        end
    endtask

    task automatic apply_compensation;
        reg signed [63:0] acc;
        begin
            // X′
            acc = $signed(fp_multiply(comp00, xyz_values[31:0])) +
                  $signed(fp_multiply(comp01, xyz_values[63:32])) +
                  $signed(fp_multiply(comp02, xyz_values[95:64]));
            xyz_adapted[31:0] = clamp_pos(acc[31:0]);

            // Y′
            acc = $signed(fp_multiply(comp10, xyz_values[31:0])) +
                  $signed(fp_multiply(comp11, xyz_values[63:32])) +
                  $signed(fp_multiply(comp12, xyz_values[95:64]));
            xyz_adapted[63:32] = clamp_pos(acc[31:0]);

            // Z′
            acc = $signed(fp_multiply(comp20, xyz_values[31:0])) +
                  $signed(fp_multiply(comp21, xyz_values[63:32])) +
                  $signed(fp_multiply(comp22, xyz_values[95:64]));
            xyz_adapted[95:64] = clamp_pos(acc[31:0]);
        end
    endtask

    task automatic xyz_to_rgb;
        reg signed [63:0] acc;
        begin
            // R
            acc = $signed(fp_multiply(M_XYZ_TO_RGB_00, xyz_adapted[31:0])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_01, xyz_adapted[63:32])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_02, xyz_adapted[95:64]));
            rgb_linear_out[31:0] = clamp_pos(acc[31:0]);

            // G
            acc = $signed(fp_multiply(M_XYZ_TO_RGB_10, xyz_adapted[31:0])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_11, xyz_adapted[63:32])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_12, xyz_adapted[95:64]));
            rgb_linear_out[63:32] = clamp_pos(acc[31:0]);

            // B
            acc = $signed(fp_multiply(M_XYZ_TO_RGB_20, xyz_adapted[31:0])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_21, xyz_adapted[63:32])) +
                  $signed(fp_multiply(M_XYZ_TO_RGB_22, xyz_adapted[95:64]));
            rgb_linear_out[95:64] = clamp_pos(acc[31:0]);
        end
    endtask

    /* ==================================================================
     *  Gamma helpers
     * =================================================================*/

    // Remove sRGB gamma (approx.)
    function automatic [31:0] gamma_remove;
        input [7:0] s;
        reg   [31:0] nrm;
        begin
            // normalize to 0‑1 as Q16.16
            nrm = (s <<< FRAC_BITS) / 8'd255;
            // crude 2.2 power ≈ nrm^2 * nrm^0.2
            gamma_remove = fp_multiply(fp_multiply(nrm, nrm), 32'h0000_D99A);
        end
    endfunction

    // Apply sRGB gamma (approx.)
    function automatic [7:0] gamma_apply;
        input signed [31:0] lin;
        reg   signed [31:0] pos, g;
        begin
            pos = lin[31] ? 32'sd0 : lin;
            // √ via two Newton iterations
            g = 32'h0000_8000;
            g = (g + fp_divide(pos, g)) >>> 1;
            g = (g + fp_divide(pos, g)) >>> 1;
            g = fp_multiply(g, 32'h0001_1000);
            gamma_apply = (g * 8'd255) >>> FRAC_BITS;
        end
    endfunction

    /* =====================================================================
     *  Main FSM
     * ===================================================================*/

    reg is_ident_matrix;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // async reset
            state            <= IDLE;
            busy             <= 1'b0;
            input_ready      <= 1'b1;
            output_valid     <= 1'b0;
            {r_in,g_in,b_in} <= 0;
            {r_out,g_out,b_out} <= 0;
            rgb_linear       <= 0;
            xyz_values       <= 0;
            xyz_adapted      <= 0;
            rgb_linear_out   <= 0;
            output_rgb       <= 0;
            is_ident_matrix  <= 1'b0;
        end else begin
            // default strobes
            output_valid <= 1'b0;

            case (state)
                IDLE: begin
                    busy        <= 1'b0;
                    input_ready <= 1'b1;
                    if (input_valid && matrix_valid) begin
                        {r_in,g_in,b_in} <= input_rgb;
                        input_ready      <= 1'b0;
                        busy             <= 1'b1;
                        // quick identity‑matrix sniff (only diag = 1.0 checked)
                        is_ident_matrix  <= (comp00 == FP_ONE) &&
                                            (comp11 == FP_ONE) &&
                                            (comp22 == FP_ONE);
                        state <= RGB_TO_XYZ;
                    end
                end

                RGB_TO_XYZ: begin
                    // gamma removal (combinational approx)
                    rgb_linear[31:0]  <= gamma_remove(r_in);
                    rgb_linear[63:32] <= gamma_remove(g_in);
                    rgb_linear[95:64] <= gamma_remove(b_in);

                    if (is_ident_matrix) begin
                        // shortcut path – just re‑apply gamma
                        r_out  <= r_in;
                        g_out  <= g_in;
                        b_out  <= b_in;
                        state  <= OUTPUT;
                    end else begin
                        state <= APPLY_COMP;
                    end
                end

                APPLY_COMP: begin
                    rgb_to_xyz;          // R′G′B′ → X,Y,Z
                    apply_compensation;  // Bradford
                    state <= XYZ_TO_RGB;
                end

                XYZ_TO_RGB: begin
                    xyz_to_rgb;          // back to linear RGB
                    r_out <= gamma_apply(rgb_linear_out[31:0]);
                    g_out <= gamma_apply(rgb_linear_out[63:32]);
                    b_out <= gamma_apply(rgb_linear_out[95:64]);
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    output_rgb   <= {r_out, g_out, b_out};
                    output_valid <= 1'b1;
                    state        <= IDLE;
                end
            endcase
        end
    end
endmodule
