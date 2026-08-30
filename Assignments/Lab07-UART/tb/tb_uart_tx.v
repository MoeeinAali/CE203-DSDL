`timescale 1ns/1ps
`include "uart_pkg.vh"

module tb_uart_tx;
    localparam integer OSD = 3;                    
    localparam integer OS  = `UART_OVERSAMPLE;    

    reg                       Clk = 1'b0;
    reg                       RstN = 1'b1;
    reg                       tx_start = 1'b0;
    reg [`UART_DATA_BITS-1:0] tx_data  = 7'd0;

    wire os_tick;
    wire txd_e, busy_e, done_e;
    wire txd_o, busy_o, done_o;

    baud_gen #(.DIVISOR(OSD)) u_baud (.Clk(Clk), .RstN(RstN), .tick(os_tick));

    uart_tx #(.ODD_PARITY(1'b0)) dut_even (
        .Clk(Clk), .RstN(RstN), .os_tick(os_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .txd(txd_e), .tx_busy(busy_e), .tx_done(done_e)
    );

    uart_tx #(.ODD_PARITY(1'b1)) dut_odd (
        .Clk(Clk), .RstN(RstN), .os_tick(os_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .txd(txd_o), .tx_busy(busy_o), .tx_done(done_o)
    );

    always #5 Clk = ~Clk;

    integer ntick = 0;
    always @(posedge Clk) if (os_tick) ntick = ntick + 1;

    integer pass = 0, fail = 0;
    integer c, i, t0;
    reg [9:0] exp;
    reg       got_done_e, got_done_o;

    always @(posedge Clk) begin
        if (done_e) got_done_e <= 1'b1;
        if (done_o) got_done_o <= 1'b1;
    end

    task automatic chk;
        input [255:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s", $time, name);
            end
        end
    endtask

    task automatic wait_tick;
        input integer target;
        begin
            while (ntick < target) @(posedge Clk);
            @(negedge Clk);
        end
    endtask

    function [9:0] frame;
        input [`UART_DATA_BITS-1:0] d;
        input                       odd;
        begin
            frame = {1'b0, odd ? ~(^d) : (^d), d[6], d[5], d[4], d[3], d[2], d[1], d[0], 1'b1};
        end
    endfunction

    initial begin
        got_done_e = 1'b0;
        got_done_o = 1'b0;

        @(negedge Clk); RstN = 1'b0;
        repeat (4) @(negedge Clk); RstN = 1'b1;
        repeat (2) @(negedge Clk);

        chk("line idles high (even)", txd_e === 1'b1);
        chk("line idles high (odd)",  txd_o === 1'b1);
        chk("not busy after reset",   busy_e === 1'b0 && busy_o === 1'b0);

        for (c = 0; c < 128; c = c + 1) begin
            @(negedge Clk); tx_data = c[6:0]; tx_start = 1'b1;
            @(negedge Clk); tx_start = 1'b0;
            t0 = ntick;

            got_done_e = 1'b0;
            got_done_o = 1'b0;

            for (i = 0; i < `UART_FRAME_BITS; i = i + 1) begin
                wait_tick(t0 + OS*i + OS/2);      
                exp = frame(c[6:0], 1'b0);
                chk("even-parity frame bit", txd_e === exp[9-i]);
                exp = frame(c[6:0], 1'b1);
                chk("odd-parity frame bit",  txd_o === exp[9-i]);
                if (i < `UART_FRAME_BITS - 1)
                    chk("busy during frame", busy_e === 1'b1 && busy_o === 1'b1);
            end

            wait_tick(t0 + OS*`UART_FRAME_BITS + 1);
            chk("tx_done pulsed",      got_done_e && got_done_o);
            chk("idle again",          busy_e === 1'b0 && busy_o === 1'b0);
            chk("line back to idle 1", txd_e === 1'b1 && txd_o === 1'b1);
        end

        @(negedge Clk); tx_data = 7'h55; tx_start = 1'b1;
        @(negedge Clk); tx_start = 1'b0;
        t0 = ntick;
        wait_tick(t0 + OS + OS/2);             
        @(negedge Clk); tx_data = 7'h2A; tx_start = 1'b1;
        @(negedge Clk); tx_start = 1'b0;
        for (i = 1; i < `UART_FRAME_BITS; i = i + 1) begin
            wait_tick(t0 + OS*i + OS/2);
            exp = frame(7'h55, 1'b0);
            chk("frame unaffected by mid-frame request", txd_e === exp[9-i]);
        end

        $display("tb_uart_tx: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
