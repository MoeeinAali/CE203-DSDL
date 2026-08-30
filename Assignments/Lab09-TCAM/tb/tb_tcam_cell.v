`timescale 1ns/1ps

// The ternary cell, tested exhaustively.
//
// A single cell has only three inputs that matter -- the stored value, the
// stored care bit and the search bit -- so "exhaustive" here means all eight
// combinations, checked against the truth table written straight out of the
// definition of the three symbols {0, 1, X}.
module tb_tcam_cell;
    reg  Clk = 1'b0, RstN = 1'b1, we = 1'b0, d = 1'b0, care = 1'b0, s = 1'b0;
    wire agree, d_q, care_q;

    tcam_cell dut (
        .Clk(Clk), .RstN(RstN), .we(we), .d(d), .care(care), .s(s),
        .agree(agree), .d_q(d_q), .care_q(care_q)
    );

    always #5 Clk = ~Clk;

    integer pass = 0, fail = 0;
    integer vi, ci, si;
    reg expect_agree;

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s (d=%b care=%b s=%b agree=%b want=%b)",
                         $time, name, d_q, care_q, s, agree, expect_agree);
            end
        end
    endtask

    task automatic store;
        input v;
        input c;
        begin
            @(negedge Clk); d = v; care = c; we = 1'b1;
            @(negedge Clk); we = 1'b0;
        end
    endtask

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);

        // After reset the cell holds X, which agrees with anything. This is
        // exactly why the entry above it needs a validity bit.
        chk("reset stores X (care = 0)", care_q === 1'b0);
        s = 1'b0; #1; chk("reset cell agrees with 0", agree === 1'b1);
        s = 1'b1; #1; chk("reset cell agrees with 1", agree === 1'b1);

        // ---- all eight combinations ----
        for (vi = 0; vi < 2; vi = vi + 1)
        for (ci = 0; ci < 2; ci = ci + 1) begin
            store(vi[0], ci[0]);
            chk("stored value read back", d_q === vi[0]);
            chk("stored care read back",  care_q === ci[0]);
            for (si = 0; si < 2; si = si + 1) begin
                s = si[0]; #1;
                // X agrees with everything; 0 and 1 agree only with themselves.
                expect_agree = (ci[0] == 1'b0) ? 1'b1 : (vi[0] == si[0]);
                chk("truth table", agree === expect_agree);
            end
        end

        // ---- a cell is only rewritten when we is high ----
        store(1'b1, 1'b1);
        @(negedge Clk); d = 1'b0; care = 1'b1; we = 1'b0;
        @(negedge Clk);
        chk("no write without we", d_q === 1'b1 && care_q === 1'b1);

        $display("tb_tcam_cell: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
