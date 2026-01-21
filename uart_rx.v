// uart_rx.v
module uart_rx #(
    parameter CLK_PER_BIT = 87
)(
    input clk,
    input rst_n,
    input rx,
    output reg done,
    output reg [7:0] data_out
);

    reg [3:0] bit_idx;
    reg [15:0] clk_cnt;
    reg [7:0] rx_shift;
    reg [1:0] state;

    // Double flop synchronizer for RX input
    reg rx_sync1, rx_sync2;

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            clk_cnt <= 0;
            bit_idx <= 0;
            data_out <= 0;
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end else begin
            // Synchronize Async RX signal
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            done <= 0;
            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (!rx_sync2) begin // Detect Falling Edge (Start Bit)
                        state <= START;
                    end
                end
                START: begin
                    // Wait for middle of start bit
                    if (clk_cnt == (CLK_PER_BIT / 2)) begin
                        if (!rx_sync2) begin // Check if still low (valid start)
                            clk_cnt <= 0;
                            state <= DATA;
                        end
                        else begin
                            state <= IDLE; // False start glitch
                        end
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLK_PER_BIT-1) begin
                        clk_cnt <= 0;
                        rx_shift[bit_idx] <= rx_sync2;
                        if (bit_idx == 7)
                            state <= STOP;
                        else
                            bit_idx <= bit_idx + 1;
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                STOP: begin
                    // Wait for stop bit time
                    if (clk_cnt == CLK_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state <= IDLE;
                        data_out <= rx_shift;
                        done <= 1;
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule
