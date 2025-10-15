// haar_cascade_rom.v
// Read-Only Memory for Haar Cascade stage and classifier data
// Stores stage thresholds and weak classifier parameters

module haar_cascade_rom #(
    parameter ADDR_WIDTH = 14,  // Address width (supports up to 16K entries)
    parameter DATA_WIDTH = 32   // Data width (32-bit for floats and indices)
)(
    input clk,
    input [ADDR_WIDTH-1:0] address,
    output reg [DATA_WIDTH-1:0] data
);

    // Memory array to hold cascade data
    // Size calculated from parsed data: ~3000 classifiers * 2 lines each + stages
    reg [DATA_WIDTH-1:0] cascade_memory [0:16383];
    
    // Load the cascade data from the memory file
    initial begin
        $readmemh("../data/cascade_data.mem", cascade_memory);
        $display("Haar Cascade ROM loaded successfully");
    end
    
    // Synchronous read
    always @(posedge clk) begin
        data <= cascade_memory[address];
    end

endmodule
