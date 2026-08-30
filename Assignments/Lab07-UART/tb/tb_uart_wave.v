`timescale 1ns/1ps
`include "uart_pkg.vh"

`ifndef VCD_FILE
`define VCD_FILE "waves/uart.vcd"
`endif

module tb_uart_wave;
    localparam integer OSD = 2;    

    reg Clk = 1'b0, RstN = 1'b1;
    always #5 Clk = ~Clk;

    reg                       a_tx_start = 1'b0, b_tx_start = 1'b0;
    reg [`UART_DATA_BITS-1:0] a_tx_data  = 7'd0, b_tx_data  = 7'd0;

    wire [`UART_RX_REG_BITS-1:0] a_rx_reg, b_rx_reg;
    wire a_rx_valid, b_rx_valid, a_tx_busy, b_tx_busy;
    wire a_to_b, b_to_a;

    uart_link #(.A_OS_DIVISOR(OSD), .B_OS_DIVISOR(OSD)) link (
        .Clk(Clk), .RstN(RstN),
        .a_tx_start(a_tx_start), .a_tx_data(a_tx_data),
        .a_tx_busy(a_tx_busy), .a_tx_done(),
        .a_rx_reg(a_rx_reg), .a_rx_data(), .a_rx_valid(a_rx_valid),
        .a_parity_err(), .a_frame_err(),
        .b_tx_start(b_tx_start), .b_tx_data(b_tx_data),
        .b_tx_busy(b_tx_busy), .b_tx_done(),
        .b_rx_reg(b_rx_reg), .b_rx_data(), .b_rx_valid(b_rx_valid),
        .b_parity_err(), .b_frame_err(),
        .a_to_b(a_to_b), .b_to_a(b_to_a)
    );

    task automatic exchange;
        input [`UART_DATA_BITS-1:0] da;
        input [`UART_DATA_BITS-1:0] db;
        begin
            wait (!a_tx_busy && !b_tx_busy);
            @(negedge Clk); a_tx_data = da; b_tx_data = db;
                            a_tx_start = 1'b1; b_tx_start = 1'b1;
            @(negedge Clk); a_tx_start = 1'b0; b_tx_start = 1'b0;
            @(posedge a_rx_valid);
            @(posedge Clk);
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_uart_wave);

        @(negedge Clk); RstN = 1'b0;
        repeat (4) @(negedge Clk); RstN = 1'b1;
        repeat (6) @(negedge Clk);

        exchange(7'h4B, 7'h7A);     
        repeat (20) @(negedge Clk);
        exchange(7'h4B, 7'h7A);

        repeat (60) @(negedge Clk);
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
