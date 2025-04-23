module control_unit (
    input wire clk,
    input wire rst_n,
    
    // Status inputs from modules
    input wire als_busy,
    input wire processing_busy,
    input wire display_busy,
    
    // Status inputs from data flow
    input wire cct_valid,
    input wire xyz_valid,
    input wire matrix_valid,
    
    // User inputs
    input wire [3:0] sw,        // Switches for control settings
    
    // Control outputs
    output reg als_read_req,    // Request to read ALS sensor
    output reg [7:0] leds       // Status LEDs
);

    // States
    localparam INIT = 3'd0;
    localparam READ_ALS = 3'd1;
    localparam WAIT_CONVERT = 3'd2;
    localparam WAIT_MATRIX = 3'd3;
    localparam WAIT_PROCESS = 3'd4;
    localparam WAIT_DISPLAY = 3'd5;
    localparam IDLE = 3'd6;
    
    // Timing parameters
    localparam ALS_READ_INTERVAL = 24'd10000000;  // ~0.2s @ 50MHz
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [23:0] delay_counter;
    reg als_read_pending;
    
    // LED status indicators
    wire led_als_busy = als_busy;
    wire led_cct_valid = cct_valid;
    wire led_xyz_valid = xyz_valid;
    wire led_matrix_valid = matrix_valid;
    wire led_processing = processing_busy;
    wire led_display = display_busy;
    
    // Status LED assignments
    always @(*) begin
        leds = {led_als_busy, led_cct_valid, led_xyz_valid, 
                led_matrix_valid, led_processing, led_display, state[1:0]};
    end
    
    // Control state machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= INIT;
            next_state <= INIT;
            delay_counter <= 24'd0;
            als_read_req <= 1'b0;
            als_read_pending <= 1'b0;
        end else begin
            // Default signal values
            als_read_req <= 1'b0;
            
            // Delay counter
            if (delay_counter > 0)
                delay_counter <= delay_counter - 24'd1;
                
            // State machine
            case (state)
                INIT: begin
                    delay_counter <= 24'd1000000;  // 20ms at 50MHz
                    state <= READ_ALS;
                end
                
                READ_ALS: begin
                    if (delay_counter == 0 && !als_busy) begin
                        als_read_req <= 1'b1;
                        als_read_pending <= 1'b1;
                        state <= WAIT_CONVERT;
                    end
                end
                
                WAIT_CONVERT: begin
                    if (cct_valid) begin
                        state <= WAIT_MATRIX;
                        als_read_pending <= 1'b0;
                    end
                end
                
                WAIT_MATRIX: begin
                    if (matrix_valid) begin
                        state <= WAIT_PROCESS;
                    end
                end
                
                WAIT_PROCESS: begin
                    if (!processing_busy) begin
                        state <= WAIT_DISPLAY;
                    end
                end
                
                WAIT_DISPLAY: begin
                    if (!display_busy) begin
                        state <= IDLE;
                        delay_counter <= ALS_READ_INTERVAL;
                    end
                end
                
                IDLE: begin
                    // Wait for delay before next ALS reading
                    if (delay_counter == 0) begin
                        state <= READ_ALS;
                    end
                end
                
                default: begin
                    state <= INIT;
                end
            endcase
        end
    end

endmodule 