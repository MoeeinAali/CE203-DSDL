`timescale 1ns/1ps
`include "tcam_pkg.vh"

module tb_tcam_entry;
    reg                    Clk = 1'b0, RstN = 1'b1;
    reg                    we = 1'b0, wvalid = 1'b1;
    reg [`TCAM_WIDTH-1:0]  wdata = 16'd0, wmask = 16'd0;
    reg [`TCAM_WIDTH-1:0]  search = 16'd0;

    wire                   match;
    wire [`TCAM_WIDTH-1:0] q_value, q_mask;
    wire                   q_valid;

    tcam_entry dut (
        .Clk(Clk), .RstN(RstN),
        .we(we), .wdata(wdata), .wmask(wmask), .wvalid(wvalid),
        .search(search), .match(match),
        .q_value(q_value), .q_mask(q_mask), .q_valid(q_valid)
    );

    always #5 Clk = ~Clk;

    integer pass = 0, fail = 0;
    integer p, w, hits;
    reg     expect_match;

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s (value=%h mask=%h search=%h match=%b want=%b)",
                         $time, name, q_value, q_mask, search, match, expect_match);
            end
        end
    endtask

    task automatic store;
        input [`TCAM_WIDTH-1:0] v;
        input [`TCAM_WIDTH-1:0] m;
        input                   vld;
        begin
            @(negedge Clk); wdata = v; wmask = m; wvalid = vld; we = 1'b1;
            @(negedge Clk); we = 1'b0;
            #1;
        end
    endtask

    task automatic sweep;
        input [`TCAM_WIDTH-1:0] v;
        input [`TCAM_WIDTH-1:0] m;
        input integer           want_hits;  
        begin
            store(v, m, 1'b1);
            hits = 0;
            for (w = 0; w < 65536; w = w + 1) begin
                search = w[`TCAM_WIDTH-1:0];
                #1;
                expect_match = (((w[`TCAM_WIDTH-1:0] ^ v) & m) == {`TCAM_WIDTH{1'b0}});
                if (match !== expect_match) begin
                    fail = fail + 1;
                    $display("  FAIL @%0t: sweep value=%h mask=%h search=%h match=%b want=%b",
                             $time, v, m, search, match, expect_match);
                end else pass = pass + 1;
                if (match) hits = hits + 1;
            end
            if (want_hits >= 0) begin
                expect_match = 1'bx;
                chk("number of matching words over the whole space",
                    hits == want_hits);
            end
        end
    endtask

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk); #1;

        chk("entry invalid after reset", q_valid === 1'b0);
        search = 16'hA5A5; #1; chk("invalid entry does not match", match === 1'b0);
        search = 16'h0000; #1; chk("invalid entry does not match zero", match === 1'b0);

        sweep(16'h1234, 16'hFFFF, 1);
        sweep(16'h0000, 16'h0000, 65536);
        sweep(16'hAB00, 16'hFF00, 256);
        sweep(16'h5A5A, 16'h0F0F, 256);
        sweep(16'hFFFF, 16'h8001, 16384);
        store(16'h1234, 16'hFFFF, 1'b1);
        search = 16'h1234; #1;
        chk("stored word matches", match === 1'b1);
        store(16'h1234, 16'hFFFF, 1'b0);
        search = 16'h1234; #1;
        chk("retired entry stops matching", match === 1'b0);
        chk("contents survive retirement", q_value === 16'h1234 && q_mask === 16'hFFFF);

        $display("tb_tcam_entry: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
