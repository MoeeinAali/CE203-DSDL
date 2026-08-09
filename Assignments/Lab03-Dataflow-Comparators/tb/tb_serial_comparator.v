`timescale 1ns/1ps

// Shared stimulus for both serial comparator variants.
// Compile with -DDUT_MODULE=serial_comparator_ff  (default)
//            or -DDUT_MODULE=serial_comparator_assign
`ifndef DUT_MODULE
`define DUT_MODULE serial_comparator_ff
`endif

module tb_serial_comparator;
    reg clk, reset, A, B;
    wire GT, EQ, LT;

    `DUT_MODULE dut (
        .clk(clk), .reset(reset), .A(A), .B(B),
        .GT(GT), .EQ(EQ), .LT(LT)
    );

    integer pass, fail;

    // Present A/B while clk=0, raise clk (FF samples / master opens),
    // then drop clk (assign slave updates). Sample after falling edge.
    task automatic cycle;
        input bit_a;
        input bit_b;
        begin
            A = bit_a;
            B = bit_b;
            #2;
            clk = 1;
            #5;
            clk = 0;
            #3;
        end
    endtask

    task automatic do_reset;
        begin
            clk = 0;
            A = 0;
            B = 0;
            reset = 1;
            #4;
            reset = 0;
            #2;
        end
    endtask

    task automatic check;
        input exp_gt;
        input exp_eq;
        input exp_lt;
        input [255:0] tag;
        begin
            if (GT === exp_gt && EQ === exp_eq && LT === exp_lt) begin
                pass = pass + 1;
            end else begin
                $display("FAIL [%0s] got GEL=%b%b%b exp=%b%b%b",
                         tag, GT, EQ, LT, exp_gt, exp_eq, exp_lt);
                fail = fail + 1;
            end
        end
    endtask

    // Feed 4 bits MSB-first; check after each bit.
    // Prefix va[3:k] ≡ (va >> k) as an unsigned integer comparison.
    task automatic feed4_check;
        input [3:0] va;
        input [3:0] vb;
        input [255:0] tag;
        integer k;
        integer rem_a, rem_b;
        begin
            do_reset;
            check(1'b0, 1'b1, 1'b0, {tag, "/reset"});
            for (k = 3; k >= 0; k = k - 1) begin
                cycle(va[k], vb[k]);
                rem_a = va >> k;
                rem_b = vb >> k;
                check(rem_a > rem_b, rem_a == rem_b, rem_a < rem_b, tag);
            end
        end
    endtask

    initial begin
        pass = 0;
        fail = 0;
        clk = 0;
        reset = 0;
        A = 0;
        B = 0;

        feed4_check(4'b0000, 4'b0000, "eq_0");
        feed4_check(4'b1010, 4'b1010, "eq_A");
        feed4_check(4'b1111, 4'b1111, "eq_F");

        feed4_check(4'b1000, 4'b0111, "gt_msb");
        feed4_check(4'b0100, 4'b0011, "gt_bit2");
        feed4_check(4'b0010, 4'b0001, "gt_bit1");
        feed4_check(4'b0001, 4'b0000, "gt_lsb");

        feed4_check(4'b0111, 4'b1000, "lt_msb");
        feed4_check(4'b0011, 4'b0100, "lt_bit2");
        feed4_check(4'b0000, 4'b0001, "lt_lsb");

        // Mid-stream reset then sticky LT decision on 0001 vs 0010
        do_reset;
        cycle(1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b0, "mid_before_rst");
        do_reset;
        check(1'b0, 1'b1, 1'b0, "mid_after_rst");
        cycle(1'b0, 1'b0); check(1'b0, 1'b1, 1'b0, "reentry1");
        cycle(1'b0, 1'b0); check(1'b0, 1'b1, 1'b0, "reentry2");
        cycle(1'b0, 1'b1); check(1'b0, 1'b0, 1'b1, "reentry3");
        cycle(1'b1, 1'b0); check(1'b0, 1'b0, 1'b1, "reentry4_sticky");

        // Exhaustive 4-bit pairs (final result)
        begin : exhaustive
            integer ai, bi, k;
            reg [3:0] va, vb;
            for (ai = 0; ai < 16; ai = ai + 1) begin
                for (bi = 0; bi < 16; bi = bi + 1) begin
                    va = ai[3:0];
                    vb = bi[3:0];
                    do_reset;
                    for (k = 3; k >= 0; k = k - 1)
                        cycle(va[k], vb[k]);
                    check(ai > bi, ai == bi, ai < bi, "exh");
                end
            end
        end

        $display("tb_serial: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
