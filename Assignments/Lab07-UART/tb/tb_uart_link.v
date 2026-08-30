`timescale 1ns/1ps
`include "uart_pkg.vh"

module tb_uart_link;
    localparam integer OS = `UART_OVERSAMPLE;

    reg Clk = 1'b0, RstN = 1'b1;
    always #5 Clk = ~Clk;

    reg                       a_start = 1'b0, b_start = 1'b0;
    reg [`UART_DATA_BITS-1:0] a_data  = 7'd0, b_data  = 7'd0;
    reg                       s_astart = 1'b0, s_bstart = 1'b0;
    reg [`UART_DATA_BITS-1:0] s_adata = 7'd0, s_bdata = 7'd0;

    wire [`UART_RX_REG_BITS-1:0] ok_arx, ok_brx;
    wire ok_avld, ok_bvld, ok_ape, ok_afe, ok_bpe, ok_bfe;
    wire ok_abusy, ok_bbusy, ok_adone, ok_bdone, ok_ab, ok_ba;

    uart_link #(.A_OS_DIVISOR(3), .B_OS_DIVISOR(3)) link_ok (
        .Clk(Clk), .RstN(RstN),
        .a_tx_start(a_start), .a_tx_data(a_data),
        .a_tx_busy(ok_abusy), .a_tx_done(ok_adone),
        .a_rx_reg(ok_arx), .a_rx_data(), .a_rx_valid(ok_avld),
        .a_parity_err(ok_ape), .a_frame_err(ok_afe),
        .b_tx_start(b_start), .b_tx_data(b_data),
        .b_tx_busy(ok_bbusy), .b_tx_done(ok_bdone),
        .b_rx_reg(ok_brx), .b_rx_data(), .b_rx_valid(ok_bvld),
        .b_parity_err(ok_bpe), .b_frame_err(ok_bfe),
        .a_to_b(ok_ab), .b_to_a(ok_ba)
    );

    wire [`UART_RX_REG_BITS-1:0] sk_arx, sk_brx;
    wire sk_avld, sk_bvld, sk_ape, sk_afe, sk_bpe, sk_bfe, sk_abusy, sk_bbusy;

    uart_link #(.A_OS_DIVISOR(20), .B_OS_DIVISOR(21)) link_skew (
        .Clk(Clk), .RstN(RstN),
        .a_tx_start(s_astart), .a_tx_data(s_adata),
        .a_tx_busy(sk_abusy), .a_tx_done(),
        .a_rx_reg(sk_arx), .a_rx_data(), .a_rx_valid(sk_avld),
        .a_parity_err(sk_ape), .a_frame_err(sk_afe),
        .b_tx_start(s_bstart), .b_tx_data(s_bdata),
        .b_tx_busy(sk_bbusy), .b_tx_done(),
        .b_rx_reg(sk_brx), .b_rx_data(), .b_rx_valid(sk_bvld),
        .b_parity_err(sk_bpe), .b_frame_err(sk_bfe),
        .a_to_b(), .b_to_a()
    );

    integer pass = 0, fail = 0;
    integer c;

    reg okA_seen, okB_seen, skA_seen, skB_seen;
    reg [`UART_RX_REG_BITS-1:0] okA_reg, okB_reg, skA_reg, skB_reg;
    reg okA_err, okB_err, skA_err, skB_err;

    always @(posedge Clk) begin
        if (ok_avld) begin okA_seen <= 1'b1; okA_reg <= ok_arx; okA_err <= ok_ape | ok_afe; end
        if (ok_bvld) begin okB_seen <= 1'b1; okB_reg <= ok_brx; okB_err <= ok_bpe | ok_bfe; end
        if (sk_avld) begin skA_seen <= 1'b1; skA_reg <= sk_arx; skA_err <= sk_ape | sk_afe; end
        if (sk_bvld) begin skB_seen <= 1'b1; skB_reg <= sk_brx; skB_err <= sk_bpe | sk_bfe; end
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

    task automatic exchange;
        input [`UART_DATA_BITS-1:0] da;
        input [`UART_DATA_BITS-1:0] db;
        begin
            wait (!ok_abusy && !ok_bbusy);
            okA_seen = 1'b0; okB_seen = 1'b0; okA_err = 1'b0; okB_err = 1'b0;
            @(negedge Clk); a_data = da; b_data = db; a_start = 1'b1; b_start = 1'b1;
            @(negedge Clk); a_start = 1'b0; b_start = 1'b0;
            wait (okA_seen && okB_seen);
            @(negedge Clk);
        end
    endtask

    task automatic exchange_skew;
        input [`UART_DATA_BITS-1:0] da;
        input [`UART_DATA_BITS-1:0] db;
        begin
            wait (!sk_abusy && !sk_bbusy);
            skA_seen = 1'b0; skB_seen = 1'b0; skA_err = 1'b0; skB_err = 1'b0;
            @(negedge Clk); s_adata = da; s_bdata = db; s_astart = 1'b1; s_bstart = 1'b1;
            @(negedge Clk); s_astart = 1'b0; s_bstart = 1'b0;
            wait (skA_seen && skB_seen);
            @(negedge Clk);
        end
    endtask

    initial begin
        okA_seen = 1'b0; okB_seen = 1'b0; skA_seen = 1'b0; skB_seen = 1'b0;
        okA_err  = 1'b0; okB_err  = 1'b0; skA_err  = 1'b0; skB_err  = 1'b0;

        @(negedge Clk); RstN = 1'b0;
        repeat (4) @(negedge Clk); RstN = 1'b1;
        repeat (4) @(negedge Clk);

        chk("both lines idle high", ok_ab === 1'b1 && ok_ba === 1'b1);

        for (c = 0; c < 128; c = c + 1) begin
            exchange(c[6:0], ~c[6:0]);
            chk("B received A's character", okB_reg === {^c[6:0], c[6:0]});
            chk("A received B's character", okA_reg === {^(~c[6:0]), ~c[6:0]});
            chk("no errors on either end",  !okA_err && !okB_err);
        end

        wait (!ok_abusy);
        okB_seen = 1'b0;
        @(negedge Clk); a_data = 7'h48; a_start = 1'b1; 
        @(negedge Clk); a_start = 1'b0;
        @(posedge ok_adone);
        @(negedge Clk); a_data = 7'h69; a_start = 1'b1; 
        @(negedge Clk); a_start = 1'b0;
        wait (okB_seen); chk("burst 'H'", okB_reg[`UART_DATA_BITS-1:0] === 7'h48);
        okB_seen = 1'b0;
        wait (okB_seen); chk("burst 'i'", okB_reg[`UART_DATA_BITS-1:0] === 7'h69);
        wait (!ok_abusy && !ok_bbusy);

        chk("both units idle at the end", !ok_abusy && !ok_bbusy);

        for (c = 0; c < 16; c = c + 1) begin
            exchange_skew({c[3:0], 3'b101}, {3'b010, c[3:0]});
            chk("skewed link: B received A", skB_reg === {^{c[3:0], 3'b101}, c[3:0], 3'b101});
            chk("skewed link: A received B", skA_reg === {^{3'b010, c[3:0]}, 3'b010, c[3:0]});
            chk("skewed link: no errors",    !skA_err && !skB_err);
        end

        $display("tb_uart_link: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
