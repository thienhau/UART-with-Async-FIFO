module uart_full_duplex #(
    parameter CLK_PER_BIT = 87
)(
    // System Interface
    input sys_clk,
    input sys_rst_n,
    input tx_push,
    input [7:0] tx_data_in,
    output tx_fifo_full,
    input rx_pop,
    output [7:0] rx_data_out,
    output rx_fifo_empty,
    // UART Interface
    input uart_clk,
    input uart_rst_n,
    output uart_tx_pin,
    input uart_rx_pin
);

    // Signals
    wire [7:0] tx_fifo_dout;
    wire tx_fifo_empty_int;
    reg tx_fifo_rd_en;
    reg uart_tx_start;
    reg [7:0] uart_tx_buffer;
    wire uart_tx_busy;
    wire [7:0] uart_rx_byte;
    wire uart_rx_done;
    wire rx_fifo_full_int;

    // Instantiations
    // 1. TX FIFO
    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) fifo_tx (
        .w_clk(sys_clk),
        .w_rst_n(sys_rst_n),
        .w_en(tx_push),
        .w_data(tx_data_in),
        .w_full(tx_fifo_full),
        .r_clk(uart_clk),
        .r_rst_n(uart_rst_n),
        .r_en(tx_fifo_rd_en),
        .r_data(tx_fifo_dout),
        .r_empty(tx_fifo_empty_int)
    );

    // 2. RX FIFO
    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) fifo_rx (
        .w_clk(uart_clk),
        .w_rst_n(uart_rst_n),
        .w_en(uart_rx_done),
        .w_data(uart_rx_byte),
        .w_full(rx_fifo_full_int),
        .r_clk(sys_clk),
        .r_rst_n(sys_rst_n),
        .r_en(rx_pop),
        .r_data(rx_data_out),
        .r_empty(rx_fifo_empty)
    );

    // 3. UART TX
    uart_tx #(.CLK_PER_BIT(CLK_PER_BIT)) tx_inst (
        .clk(uart_clk),
        .rst_n(uart_rst_n),
        .data_in(uart_tx_buffer),
        .start(uart_tx_start),
        .tx(uart_tx_pin),
        .busy(uart_tx_busy)
    );

    // 4. UART RX
    uart_rx #(.CLK_PER_BIT(CLK_PER_BIT)) rx_inst (
        .clk(uart_clk),
        .rst_n(uart_rst_n),
        .rx(uart_rx_pin),
        .done(uart_rx_done),
        .data_out(uart_rx_byte)
    );

    // CONTROL LOGIC (TX FSM)
    reg [1:0] tx_fsm;
    localparam S_IDLE = 0, S_FETCH = 1, S_START = 2, S_WAIT_BUSY = 3;

    always @(posedge uart_clk or negedge uart_rst_n) begin
        if (!uart_rst_n) begin
            tx_fsm <= S_IDLE;
            tx_fifo_rd_en <= 0;
            uart_tx_start <= 0;
            uart_tx_buffer <= 0;
        end else begin
            case (tx_fsm)
                S_IDLE: begin
                    uart_tx_start <= 0;
                    // Only read FIFO when UART is not busy.
                    if (!tx_fifo_empty_int && !uart_tx_busy) begin
                        tx_fifo_rd_en <= 1;
                        tx_fsm <= S_FETCH;
                    end
                end
                S_FETCH: begin
                    tx_fifo_rd_en <= 0;
                    uart_tx_buffer <= tx_fifo_dout;
                    tx_fsm <= S_START;
                end
                S_START: begin
                    uart_tx_start <= 1; // Enable sending
                    tx_fsm <= S_WAIT_BUSY;
                end
                S_WAIT_BUSY: begin
                    uart_tx_start <= 0;
                    // If busy=1, UART received the command -> Go to IDLE and wait for busy=0
                    if (uart_tx_busy) begin
                        tx_fsm <= S_IDLE;
                    end
                    // Fallback: UART TX is set to busy immediately after 1 cycle,
                    // so this state keeps the FSM for exactly 1 cycle as needed.
                end
            endcase
        end
    end
endmodule