`timescale 1ns / 1ps

module tb_uart_full_duplex;

    // Parameters
    parameter CLK_PER_BIT = 87;
    parameter SYS_CLK_PERIOD = 10;   // 100MHz
    parameter UART_CLK_PERIOD = 100; // 10MHz
    
    // Time for 1 byte (10 bits include Start/Stop)
    localparam BYTE_TIME = 10 * CLK_PER_BIT * UART_CLK_PERIOD;
    parameter SCB_DEPTH = 2048;

    // Signals
    reg sys_clk, sys_rst_n;
    reg uart_clk, uart_rst_n;
    reg tx_push;
    reg [7:0] tx_data_in;
    wire tx_fifo_full;
    reg rx_pop;
    wire [7:0] rx_data_out;
    wire rx_fifo_empty;
    wire uart_tx_pin;
    wire uart_rx_pin;

    // Scoreboard
    reg [7:0] scoreboard_mem [0:SCB_DEPTH-1];
    integer scb_wr_ptr = 0;
    integer scb_rd_ptr = 0;
    integer error_count = 0;
    integer success_count = 0;
    integer i;

    // Loopback
    assign uart_rx_pin = uart_tx_pin;

    // DUT Instantiation
    uart_full_duplex #(.CLK_PER_BIT(CLK_PER_BIT)) dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .tx_push(tx_push),
        .tx_data_in(tx_data_in),
        .tx_fifo_full(tx_fifo_full),
        .rx_pop(rx_pop),
        .rx_data_out(rx_data_out),
        .rx_fifo_empty(rx_fifo_empty),
        .uart_clk(uart_clk),
        .uart_rst_n(uart_rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin)
    );

    // Clock Generation
    initial begin 
        sys_clk = 0; 
        uart_clk = 0; 
    end
    always #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;
    always #(UART_CLK_PERIOD/2) uart_clk = ~uart_clk;

    // Tasks
    task apply_reset;
        begin
            sys_rst_n = 0; uart_rst_n = 0;
            tx_push = 0; rx_pop = 0; tx_data_in = 0;
            #200;
            sys_rst_n = 1; uart_rst_n = 1;
            #100;
            $display("[INFO] Reset Complete. Byte Time: %0d ns", BYTE_TIME);
        end
    endtask

    task send_byte(input [7:0] data);
        begin
            @(posedge sys_clk);
            while (tx_fifo_full) @(posedge sys_clk);
            tx_data_in = data;
            tx_push = 1;
            scoreboard_mem[scb_wr_ptr] = data;
            scb_wr_ptr = scb_wr_ptr + 1;
            @(posedge sys_clk);
            tx_push = 0;
            tx_data_in = 0;
        end
    endtask

    task send_burst(input [31:0] n);
        integer k;
        begin
            for(k=0; k<n; k=k+1) begin
                send_byte($random % 256);
            end
        end
    endtask

    // Monitor Process
    initial begin
        #250;
        forever begin
            @(posedge sys_clk);
            if (!rx_fifo_empty) begin
                rx_pop = 1;
                @(posedge sys_clk);
                rx_pop = 0;
                if (rx_data_out === scoreboard_mem[scb_rd_ptr]) begin
                    success_count = success_count + 1;
                end else begin
                    $display("[FAIL] Time %0t: RX=0x%h, EXP=0x%h", $time, rx_data_out, scoreboard_mem[scb_rd_ptr]);
                    error_count = error_count + 1;
                end
                scb_rd_ptr = scb_rd_ptr + 1;
            end
        end
    end

    // Main Test Sequence
    initial begin
        apply_reset();

        $display("\n--- GROUP 1: BASIC PATTERNS ---");
        $display("Test 1: 0x55"); send_byte(8'h55); #(BYTE_TIME * 1.5);
        $display("Test 2: 0xAA"); send_byte(8'hAA); #(BYTE_TIME * 1.5);
        $display("Test 3: 0x00"); send_byte(8'h00); #(BYTE_TIME * 1.5);
        $display("Test 4: 0xFF"); send_byte(8'hFF); #(BYTE_TIME * 1.5);
        $display("Test 5: Pair 0x12, 0x34"); send_byte(8'h12); send_byte(8'h34); #(BYTE_TIME * 3);

        $display("\n--- GROUP 2: FIFO STRESS ---");
        $display("Test 6: Small Burst (4 bytes)"); send_burst(4); #(BYTE_TIME * 6);
        $display("Test 7: Halfway (8 bytes)"); send_burst(8); #(BYTE_TIME * 10);
        $display("Test 8: Rapid Random (10 bytes)"); send_burst(10); #(BYTE_TIME * 12);
        $display("Test 9: Interleaved 0x55/0xAA"); 
        send_byte(8'h55); send_byte(8'hAA); send_byte(8'h55); send_byte(8'hAA); #(BYTE_TIME * 6);
        $display("Test 10: High Value Bytes"); send_byte(8'hF0); send_byte(8'hF1); #(BYTE_TIME * 3);

        $display("\n--- GROUP 3: TIMING & ASYNC ---");
        $display("Test 11: Slow Insertion"); 
        send_byte(8'hA1); #(BYTE_TIME * 2); send_byte(8'hB2); #(BYTE_TIME * 2);
        $display("Test 12: Back-to-Back Fast"); send_burst(12); #(BYTE_TIME * 15);
        
        $display("Test 13: Full FIFO Stress (Overflow wait)"); 
        // FIFO depth 16, sending 20 bytes will trigger the tx_fifo_full wait mechanism in the task.
        send_burst(20); #(BYTE_TIME * 25);

        $display("Test 14: Reset Recovery");
        sys_rst_n = 0; uart_rst_n = 0; #500;
        sys_rst_n = 1; uart_rst_n = 1; #500;
        // Resynchronize scb_rd_ptr because reset emptys DUT but doesn't delete scb array.
        scb_rd_ptr = scb_wr_ptr; 
        send_byte(8'hCC); #(BYTE_TIME * 2);

        $display("Test 15: Odd/Even Check"); send_byte(8'h02); send_byte(8'h03); #(BYTE_TIME * 3);

        $display("\n--- GROUP 4: CORNER CASES & FINAL STRESS ---");
        $display("Test 16: MSB only (0x80)"); send_byte(8'h80); #(BYTE_TIME * 1.5);
        $display("Test 17: LSB only (0x01)"); send_byte(8'h01); #(BYTE_TIME * 1.5);
        
        $display("Test 18: Random Delays");
        for (i=0; i<5; i=i+1) begin
            send_byte($random % 256);
            #({$random} % 2000); 
        end
        #(BYTE_TIME * 6);

        $display("Test 19: Long Stream Stress (1000 bytes)");
        send_burst(1000); 
        #(BYTE_TIME * 50);

        $display("Test 20: Final Verification");
        send_byte(8'hFF); send_byte(8'h00);
        #(BYTE_TIME * 5);

        $display("\n==================================================");
        $display("TESTBENCH COMPLETED");
        $display("Total Sent:      %0d", scb_wr_ptr);
        $display("Successfully Rx: %0d", success_count);
        $display("Errors Detected: %0d", error_count);
        
        if (error_count == 0 && success_count > 0) 
            $display("RESULT: **** PASSED ****");
        else 
            $display("RESULT: !!!! FAILED !!!!");
        $display("==================================================");
        
        $finish;
    end

endmodule