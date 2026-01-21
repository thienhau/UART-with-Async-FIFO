// async_fifo.v
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input w_clk,
    input w_rst_n,
    input w_en,
    input [DATA_WIDTH-1:0] w_data,
    output w_full,
    input r_clk,
    input r_rst_n,
    input r_en,
    output [DATA_WIDTH-1:0] r_data,
    output r_empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0] w_ptr_bin, w_ptr_gray;
    reg [ADDR_WIDTH:0] r_ptr_bin, r_ptr_gray;
    reg [ADDR_WIDTH:0] w_ptr_gray_sync1, w_ptr_gray_sync2; // r_clk domain
    reg [ADDR_WIDTH:0] r_ptr_gray_sync1, r_ptr_gray_sync2; // w_clk domain

    // Binary to Gray conversion
    function [ADDR_WIDTH:0] bin2gray;
        input [ADDR_WIDTH:0] bin;
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Write Domain (w_clk)
    // Synchronize r_ptr to w_clk
    always @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            r_ptr_gray_sync1 <= 0;
            r_ptr_gray_sync2 <= 0;
        end
        else begin
            r_ptr_gray_sync1 <= r_ptr_gray;
            r_ptr_gray_sync2 <= r_ptr_gray_sync1;
        end
    end

    // Write Logic
    // Convert synchronized Gray back to binary for comparison
    wire [ADDR_WIDTH:0] r_ptr_bin_sync;
    assign r_ptr_bin_sync[ADDR_WIDTH] = r_ptr_gray_sync2[ADDR_WIDTH];
    generate
        genvar i;
        for (i = ADDR_WIDTH-1; i >= 0; i = i-1) begin : gray2bin
            assign r_ptr_bin_sync[i] = r_ptr_bin_sync[i+1] ^ r_ptr_gray_sync2[i];
        end
    endgenerate

    // Full when FIFO count equals depth
    wire [ADDR_WIDTH:0] wptr_next = w_ptr_bin + 1'b1;
    assign w_full = ((wptr_next[ADDR_WIDTH-1:0] == r_ptr_bin_sync[ADDR_WIDTH-1:0]) &&
                     (wptr_next[ADDR_WIDTH] != r_ptr_bin_sync[ADDR_WIDTH]));

    always @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            w_ptr_bin <= 0;
            w_ptr_gray <= 0;
        end
        else if (w_en && !w_full) begin
            mem[w_ptr_bin[ADDR_WIDTH-1:0]] <= w_data;
            w_ptr_bin <= w_ptr_bin + 1'b1;
            w_ptr_gray <= bin2gray(w_ptr_bin + 1'b1); // Gray code of next pointer
        end
    end

    // Read Domain (r_clk)
    // Synchronize w_ptr to r_clk
    always @(posedge r_clk or negedge r_rst_n) begin
        if (!r_rst_n) begin
            w_ptr_gray_sync1 <= 0;
            w_ptr_gray_sync2 <= 0;
        end
        else begin
            w_ptr_gray_sync1 <= w_ptr_gray;
            w_ptr_gray_sync2 <= w_ptr_gray_sync1;
        end
    end

    // Read Logic
    assign r_empty = (r_ptr_gray == w_ptr_gray_sync2);
    assign r_data = mem[r_ptr_bin[ADDR_WIDTH-1:0]];

    always @(posedge r_clk or negedge r_rst_n) begin
        if (!r_rst_n) begin
            r_ptr_bin <= 0;
            r_ptr_gray <= 0;
        end
        else if (r_en && !r_empty) begin
            r_ptr_bin <= r_ptr_bin + 1'b1;
            r_ptr_gray <= bin2gray(r_ptr_bin + 1'b1); // Gray code of next pointer
        end
    end
endmodule
