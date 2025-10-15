// feature_rom.v
// Read-Only Memory for Haar feature rectangle definitions
// Each feature consists of 2-3 rectangles with coordinates and weights

module feature_rom #(
    parameter ADDR_WIDTH = 14,
    parameter DATA_WIDTH = 32
)(
    input clk,
    input [ADDR_WIDTH-1:0] address,
    output reg [DATA_WIDTH-1:0] data
);

    // Memory array to hold feature data
    // Features are stored at the end of cascade_data.mem
    // Starting from line ~6000 (after all stage data)
    reg [DATA_WIDTH-1:0] feature_memory [0:16383];
    
    // Load the same file but we'll access the feature section
    initial begin
        $readmemh("../data/cascade_data.mem", feature_memory);
        $display("Feature ROM loaded successfully");
    end
    
    // Synchronous read
    always @(posedge clk) begin
        data <= feature_memory[address];
    end

endmodule
