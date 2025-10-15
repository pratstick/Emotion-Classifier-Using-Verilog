// feature_calculator.v
// Calculates Haar feature values from rectangle sums
// Feature = sum of (rectangle_area * weight) for all rectangles in the feature

module feature_calculator #(
    parameter DATA_WIDTH = 32,
    parameter SUM_WIDTH = 24
)(
    input clk,
    input rst,
    input start,                              // Start feature calculation
    input [11:0] feature_index,               // Which feature to calculate
    input [7:0] window_x, window_y,           // Current detection window position
    input [7:0] window_scale,                 // Window scale factor
    
    // Interface to integral image
    output reg [15:0] query_x1, query_y1,
    output reg [15:0] query_x2, query_y2,
    output reg query_valid,
    input [SUM_WIDTH-1:0] rect_sum,
    input rect_sum_valid,
    
    // Interface to feature ROM
    output reg [13:0] feature_addr,
    input [DATA_WIDTH-1:0] feature_data,
    
    // Output
    output reg signed [DATA_WIDTH-1:0] feature_value,  // Calculated feature value (as float)
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam READ_NUM_RECTS = 3'b001;
    localparam READ_RECT = 3'b010;
    localparam QUERY_SUM = 3'b011;
    localparam ACCUMULATE = 3'b100;
    localparam DONE = 3'b101;
    
    reg [2:0] state;
    reg [3:0] num_rects;          // Number of rectangles in this feature
    reg [3:0] rect_counter;       // Current rectangle being processed
    reg [13:0] base_addr;         // Base address of this feature in ROM
    reg [13:0] rect_data_addr;    // Address for rectangle data
    
    // Rectangle data
    reg [15:0] rect_x, rect_y, rect_w, rect_h;
    reg signed [DATA_WIDTH-1:0] rect_weight;
    
    // Accumulator for feature value
    reg signed [DATA_WIDTH-1:0] accumulator;
    reg [2:0] read_step;          // Step for reading 5 values per rectangle
    
    // Feature section starts at line 6000 in the memory file (approximate)
    // This is where features begin after all stage data
    localparam FEATURE_SECTION_OFFSET = 14'd6000;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            feature_value <= 0;
            query_valid <= 0;
            num_rects <= 0;
            rect_counter <= 0;
            accumulator <= 0;
            read_step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= READ_NUM_RECTS;
                        accumulator <= 0;
                        rect_counter <= 0;
                        
                        // Calculate base address for this feature
                        // Each feature has variable size: 1 (count) + N_rects * 5 (data) + 1 (blank)
                        // For simplicity, we'll use a lookup or calculate offset
                        // Here we approximate: feature N starts at offset + N*7 (avg 2 rects/feature)
                        base_addr <= FEATURE_SECTION_OFFSET + (feature_index * 7);
                        feature_addr <= FEATURE_SECTION_OFFSET + (feature_index * 7);
                    end
                end
                
                READ_NUM_RECTS: begin
                    // Read number of rectangles (1 cycle delay for ROM)
                    num_rects <= feature_data[3:0];  // Lower bits contain count
                    state <= READ_RECT;
                    read_step <= 0;
                    rect_data_addr <= base_addr + 1;  // First rect starts after count
                    feature_addr <= base_addr + 1;
                end
                
                READ_RECT: begin
                    // Read rectangle data: x, y, w, h, weight (5 lines)
                    case (read_step)
                        0: begin
                            rect_x <= feature_data[15:0];
                            feature_addr <= rect_data_addr + 1;
                            read_step <= 1;
                        end
                        1: begin
                            rect_y <= feature_data[15:0];
                            feature_addr <= rect_data_addr + 2;
                            read_step <= 2;
                        end
                        2: begin
                            rect_w <= feature_data[15:0];
                            feature_addr <= rect_data_addr + 3;
                            read_step <= 3;
                        end
                        3: begin
                            rect_h <= feature_data[15:0];
                            feature_addr <= rect_data_addr + 4;
                            read_step <= 4;
                        end
                        4: begin
                            rect_weight <= feature_data;  // Weight is a float
                            state <= QUERY_SUM;
                            read_step <= 0;
                        end
                    endcase
                end
                
                QUERY_SUM: begin
                    // Query integral image for rectangle sum
                    // Scale rectangle coordinates by window position and scale
                    query_x1 <= window_x + ((rect_x * window_scale) >> 8);
                    query_y1 <= window_y + ((rect_y * window_scale) >> 8);
                    query_x2 <= window_x + (((rect_x + rect_w) * window_scale) >> 8) - 1;
                    query_y2 <= window_y + (((rect_y + rect_h) * window_scale) >> 8) - 1;
                    query_valid <= 1;
                    // Stay in QUERY_SUM state until we get a response
                    if (rect_sum_valid) begin
                        query_valid <= 0;
                        state <= ACCUMULATE;
                    end
                end
                
                ACCUMULATE: begin
                    // Process the received rect_sum
                    if (1) begin  // rect_sum is already valid from previous state
                        // Accumulate: feature_value += rect_sum * weight
                        // Note: This is simplified - actual implementation needs float multiply
                        accumulator <= accumulator + (rect_sum * rect_weight);
                        
                        // Move to next rectangle
                        rect_counter <= rect_counter + 1;
                        if (rect_counter + 1 >= num_rects) begin
                            state <= DONE;
                        end else begin
                            state <= READ_RECT;
                            rect_data_addr <= rect_data_addr + 5;
                            feature_addr <= rect_data_addr + 5;
                        end
                    end
                end
                
                DONE: begin
                    feature_value <= accumulator;
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
