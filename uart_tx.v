// uart_tx.v
module uart_tx #(
    parameter CLK_PER_BIT = 87
)(
    input clk,
    input rst_n,
    input [7:0] data_in,
    input start,
    output reg tx,
    output reg busy
);

    reg [3:0] bit_idx;
    reg [15:0] clk_cnt;
    reg [7:0] tx_shift;
    reg [1:0] state;

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;
            busy <= 0;
            clk_cnt <= 0;
            bit_idx <= 0;
            tx_shift <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (start) begin
                        tx_shift <= data_in;
                        state <= START;
                        busy <= 1;
                    end
                    else begin
                        busy <= 0;
                    end
                end
                START: begin
                    tx <= 0; // Start bit = 0
                    if (clk_cnt == CLK_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state <= DATA;
                    end
                    else clk_cnt <= clk_cnt + 1;
                end
                DATA: begin
                    tx <= tx_shift[bit_idx];
                    if (clk_cnt == CLK_PER_BIT-1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 7)
                            state <= STOP;
                        else
                            bit_idx <= bit_idx + 1;
                    end
                    else clk_cnt <= clk_cnt + 1;
                end
                STOP: begin
                    tx <= 1; // Stop bit = 1
                    if (clk_cnt == CLK_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state <= IDLE;
                        busy <= 0; // Done
                    end
                    else clk_cnt <= clk_cnt + 1;
                end
            endcase
        end
    end
endmodule
