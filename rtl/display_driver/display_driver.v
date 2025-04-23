module display_driver (
    input wire clk,
    input wire rst_n,
    
    // Input RGB data from image processor
    input wire [23:0] input_rgb,        // RGB input (8 bits per channel)
    input wire input_valid,             // Input data valid
    
    // Output RGB data to display
    output reg [23:0] output_rgb,       // RGB output (8 bits per channel)
    output reg output_valid,            // Output data valid
    input wire output_ready,            // Display is ready to accept data
    
    // Status
    output reg busy                     // Display driver is busy
);

    // State machine definitions
    localparam IDLE = 2'd0;
    localparam BUFFER = 2'd1;
    localparam SEND = 2'd2;
    localparam WAIT = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [23:0] rgb_buffer;             // Buffer for RGB data
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            output_valid <= 1'b0;
            output_rgb <= 24'd0;
            rgb_buffer <= 24'd0;
        end else begin
            // Default values
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    
                    if (input_valid) begin
                        // Buffer the input data
                        rgb_buffer <= input_rgb;
                        busy <= 1'b1;
                        state <= BUFFER;
                    end
                end
                
                BUFFER: begin
                    // Check if display is ready to receive new data
                    if (output_ready) begin
                        output_rgb <= rgb_buffer;
                        output_valid <= 1'b1;
                        state <= SEND;
                    end
                end
                
                SEND: begin
                    // Data has been sent, wait for display to process
                    output_valid <= 1'b0;
                    state <= WAIT;
                end
                
                WAIT: begin
                    // Artificial delay to simulate display refresh time
                    // In a real implementation, would wait for display ready signal
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule 