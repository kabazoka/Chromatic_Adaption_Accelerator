module cct_to_xyz_converter (
    input wire clk,
    input wire rst_n,
    
    // Input from ALS sensor
    input wire [15:0] cct_in,        // Color temperature in Kelvin
    input wire cct_valid,            // CCT value is valid
    
    // Output XYZ values
    output reg [95:0] xyz_out,       // X, Y, Z values in fixed-point format
    output reg xyz_valid             // XYZ values are valid
);

    // Fixed-point format settings (Q16.16)
    localparam INT_BITS = 16;
    localparam FRAC_BITS = 16;
    localparam Q_FORMAT = 32;  // Total bits
    
    // State machine definitions
    localparam IDLE = 2'd0;
    localparam CALC_XY = 2'd1;
    localparam CALC_XYZ = 2'd2;
    localparam DONE = 2'd3;
    
    // CCT bounds
    localparam CCT_MIN = 16'd3000;  // 3000K
    localparam CCT_MAX = 16'd8000;  // 8000K
    
    // Fixed-point 1.0 in Q16.16 format
    localparam FP_ONE = 32'h00010000;
    
    // Internal registers
    reg [1:0] state;
    reg [15:0] cct_value;
    reg [31:0] x_coord;  // Chromaticity x in fixed-point
    reg [31:0] y_coord;  // Chromaticity y in fixed-point
    reg [31:0] one_minus_x_minus_y; // Temporary variable for Z calculation
    
    // Fixed-point arithmetic helper functions
    function [31:0] fp_multiply;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] result;
        begin
            result = a * b;
            fp_multiply = result >> FRAC_BITS;
        end
    endfunction
    
    function [31:0] fp_divide;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] temp_a;
        reg [63:0] result;
        begin
            // Debug
            $display("cct_to_xyz fp_divide: a=%h (%f), b=%h (%f)", 
                     a, $itor(a) / 65536.0, 
                     b, $itor(b) / 65536.0);
                     
            // Check for division by zero or very small values
            if ((b == 0) || (b < 32'h00000080)) begin // Avoid division by very small values
                $display("cct_to_xyz fp_divide: Division by zero or very small value detected!");
                if (a == 0)
                    result = 0; // 0/0 = 0
                else if (a[31] == b[31]) 
                    result = 64'h000000007FFFFFFF; // Max positive value
                else
                    result = 64'hFFFFFFFF80000000; // Min negative value
            end else begin
                // Perform fixed-point division
                temp_a = {32'h00000000, a};  // Extend to 64 bits
                temp_a = temp_a << FRAC_BITS;
                result = temp_a / b;
                
                // Debug
                $display("cct_to_xyz fp_divide: temp_a=%h, result=%h (%f)", 
                         temp_a, result, $itor(result[31:0]) / 65536.0);
                         
                // Saturate result if it exceeds 32-bit range
                if (result > 64'h000000007FFFFFFF)
                    result = 64'h000000007FFFFFFF;
                else if (result < 64'hFFFFFFFF80000000)
                    result = 64'hFFFFFFFF80000000;
            end
            fp_divide = result[31:0];
        end
    endfunction
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            cct_value <= 16'd0;
            x_coord <= 32'd0;
            y_coord <= 32'd0;
            one_minus_x_minus_y <= 32'd0;
            xyz_out <= 96'd0;
            xyz_valid <= 1'b0;
        end else begin
            // Default signal values
            xyz_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (cct_valid) begin
                        cct_value <= (cct_in < CCT_MIN) ? CCT_MIN : 
                                   (cct_in > CCT_MAX) ? CCT_MAX : cct_in;
                        state <= CALC_XY;
                    end
                end
                
                CALC_XY: begin
                    // Convert CCT to xy coordinates using McCamy's approximation
                    // This is a simplified model - a real implementation would use 
                    // more accurate formulas or lookup tables
                    
                    // Choose chromaticity coordinates based on CCT range
                    if (cct_value >= 6400 && cct_value <= 6600) begin
                        // D65 white point (CCT 6500K): x=0.3127, y=0.3290
                        x_coord <= 32'h00005019; // 0.3127 in Q16.16
                        y_coord <= 32'h000054A7; // 0.3290 in Q16.16
                    end else if (cct_value <= 5000) begin
                        // For CCT <= 5000K - approximate D50
                        x_coord <= 32'h00005C29; // 0.3608 in Q16.16
                        y_coord <= 32'h00005CA3; // 0.3609 in Q16.16
                    end else begin
                        // For CCT > 5000K and not 6500K - approximate D55
                        x_coord <= 32'h0000559A; // 0.3324 in Q16.16
                        y_coord <= 32'h00005A8F; // 0.3474 in Q16.16
                    end
                    
                    state <= CALC_XYZ;
                end
                
                CALC_XYZ: begin
                    // Convert xy coordinates to XYZ
                    // Assuming Y = 1.0
                    // X = (x/y) * Y
                    // Z = ((1-x-y)/y) * Y
                    
                    // Debug: Print chromaticity coordinates
                    $display("CCT=%dK, xy coordinates: x=%f, y=%f",
                            cct_value,
                            $itor(x_coord) / 65536.0,
                            $itor(y_coord) / 65536.0);
                    
                    // Calculate X = (x/y) * 1.0
                    xyz_out[31:0] <= fp_divide(x_coord, y_coord);
                    
                    // Y = 1.0 (fixed)
                    xyz_out[63:32] <= FP_ONE;  // 1.0 in fixed point
                    
                    // Calculate temporary value (1-x-y)
                    // Fixed-point subtraction
                    one_minus_x_minus_y = FP_ONE - x_coord - y_coord;
                    
                    // Debug: Print calculation for (1-x-y)
                    $display("1-x-y = %f", $itor(one_minus_x_minus_y) / 65536.0);
                    
                    // Calculate Z = ((1-x-y)/y) * 1.0
                    xyz_out[95:64] <= fp_divide(one_minus_x_minus_y, y_coord);
                    
                    state <= DONE;
                end
                
                DONE: begin
                    xyz_valid <= 1'b1;
                    
                    // Debug: Print final XYZ values
                    $display("Final XYZ values: X=%f, Y=%f, Z=%f",
                            $itor(xyz_out[31:0]) / 65536.0,
                            $itor(xyz_out[63:32]) / 65536.0,
                            $itor(xyz_out[95:64]) / 65536.0);
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule 