`timescale 1ns/1ps
`include "tcam_pkg.vh"

// Direct checks against the lab sheet, with no reference model involved.
//
// Patterns are written here as TEXT, in the same {0, 1, X} notation the sheet
// uses, and converted to a value/mask pair by the testbench. That keeps the
// checks readable next to the sheet and makes the value/mask encoding itself
// part of what is being verified: if the encoding were wrong, the worked
// example from the sheet would stop matching.
//
// The sheet's example is 8 bits wide and this TCAM is 16, so each pattern is
// written with its high byte marked entirely as X. That is not a workaround --
// it is the ordinary way a narrow rule is stored in a wider TCAM, and it gets
// checked here by searching with two different high bytes.
module tb_tcam_spec;
    reg                      Clk = 1'b0, RstN = 1'b1;
    reg                      we = 1'b0, wvalid = 1'b1;
    reg [`TCAM_AW-1:0]       waddr = 4'd0;
    reg [`TCAM_WIDTH-1:0]    wdata = 16'd0, wmask = 16'd0;
    reg [`TCAM_WIDTH-1:0]    search = 16'd0;
    reg [`TCAM_AW-1:0]       dbg_addr = 4'd0;

    wire [`TCAM_ENTRIES-1:0] match;
    wire                     hit;
    wire [`TCAM_AW-1:0]      match_addr;
    wire [`TCAM_CNTW-1:0]    match_count;
    wire [`TCAM_WIDTH-1:0]   dbg_value, dbg_mask;
    wire                     dbg_valid;

    tcam dut (
        .Clk(Clk), .RstN(RstN),
        .we(we), .waddr(waddr), .wdata(wdata), .wmask(wmask), .wvalid(wvalid),
        .search(search), .match(match), .hit(hit),
        .match_addr(match_addr), .match_count(match_count),
        .dbg_addr(dbg_addr), .dbg_value(dbg_value), .dbg_mask(dbg_mask),
        .dbg_valid(dbg_valid)
    );

    always #5 Clk = ~Clk;

    integer pass = 0, fail = 0;

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s (search=%h match=%h hit=%b addr=%0d cnt=%0d)",
                         $time, name, search, match, hit, match_addr, match_count);
            end
        end
    endtask

    task automatic store;
        input [`TCAM_AW-1:0]    a;
        input [`TCAM_WIDTH-1:0] v;
        input [`TCAM_WIDTH-1:0] m;
        input                   vld;
        begin
            @(negedge Clk);
            waddr = a; wdata = v; wmask = m; wvalid = vld; we = 1'b1;
            @(negedge Clk); we = 1'b0;
            #1;
        end
    endtask

    // Store a pattern written as 16 characters of '0', '1' or 'X'.
    // The leftmost character is the most significant bit.
    task automatic store_pattern;
        input [`TCAM_AW-1:0] a;
        input [8*`TCAM_WIDTH-1:0] pat;
        reg [`TCAM_WIDTH-1:0] v, m;
        reg [7:0] ch;
        integer i;
        begin
            v = {`TCAM_WIDTH{1'b0}};
            m = {`TCAM_WIDTH{1'b0}};
            for (i = 0; i < `TCAM_WIDTH; i = i + 1) begin
                ch = pat[8*(`TCAM_WIDTH-1-i) +: 8];      // i-th character
                if (ch == "1") begin
                    v[`TCAM_WIDTH-1-i] = 1'b1;
                    m[`TCAM_WIDTH-1-i] = 1'b1;
                end else if (ch == "0") begin
                    m[`TCAM_WIDTH-1-i] = 1'b1;           // value stays 0
                end
                // anything else is X: care stays 0
            end
            store(a, v, m, 1'b1);
        end
    endtask

    task automatic look;
        input [`TCAM_WIDTH-1:0] s;
        begin
            search = s; #1;
        end
    endtask

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk); #1;

        // ================================================================
        // The worked example from the lab sheet.
        //
        //   searching for 01101110, the sheet says these three are matches:
        //       X1101XXX     0X1X11X0     0110XXXX
        // ================================================================
        store_pattern(4'd0, "XXXXXXXXX1101XXX");    // sheet: match
        store_pattern(4'd1, "XXXXXXXX0X1X11X0");    // sheet: match
        store_pattern(4'd2, "XXXXXXXX0110XXXX");    // sheet: match
        store_pattern(4'd3, "XXXXXXXX1XXXXXXX");    // MSB is wrong: no match
        store_pattern(4'd4, "XXXXXXXX01101111");    // differs in the last bit
        store_pattern(4'd5, "XXXXXXXX01101110");    // exact copy of the data

        // check the value/mask encoding of the first pattern by hand:
        //   X 1 1 0 1 X X X  ->  care = 01111000, value = 01101000
        dbg_addr = 4'd0; #1;
        chk("pattern X1101XXX encodes to mask 0x0078", dbg_mask  === 16'h0078);
        chk("pattern X1101XXX encodes to value 0x0068", dbg_value === 16'h0068);

        look(16'h006E);                              // the data word 01101110
        chk("sheet: X1101XXX matches", match[0] === 1'b1);
        chk("sheet: 0X1X11X0 matches", match[1] === 1'b1);
        chk("sheet: 0110XXXX matches", match[2] === 1'b1);
        chk("1XXXXXXX does not match", match[3] === 1'b0);
        chk("01101111 does not match", match[4] === 1'b0);
        chk("01101110 matches exactly", match[5] === 1'b1);
        chk("four entries matched in total", match_count === 5'd4);
        chk("there was a hit",              hit === 1'b1);
        chk("lowest matching index wins",   match_addr === 4'd0);

        // The high byte of every pattern is X, so it really is ignored.
        look(16'hFF6E);
        chk("high byte is don't-care: same match lines",
            match[5:0] === 6'b100111 && match_count === 5'd4);
        look(16'h5A6E);
        chk("high byte is don't-care: any value works", match_count === 5'd4);

        // ================================================================
        // A neighbouring data word: 01101111 differs only in the last bit.
        // ================================================================
        look(16'h006F);
        chk("X1101XXX still matches 01101111", match[0] === 1'b1);
        chk("0X1X11X0 rejects it (last bit must be 0)", match[1] === 1'b0);
        chk("0110XXXX still matches",          match[2] === 1'b1);
        chk("01101111 now matches exactly",    match[4] === 1'b1);
        chk("01101110 no longer matches",      match[5] === 1'b0);
        chk("three entries matched",           match_count === 5'd3);

        // ================================================================
        // Priority is lowest index wins, and retiring the winner promotes
        // the next one.
        // ================================================================
        look(16'h006E);
        chk("winner is entry 0", match_addr === 4'd0);
        store(4'd0, 16'h0068, 16'h0078, 1'b0);       // retire entry 0
        look(16'h006E);
        chk("after retiring entry 0 the winner is entry 1", match_addr === 4'd1);
        chk("and one fewer entry matches",                  match_count === 5'd3);
        store(4'd0, 16'h0068, 16'h0078, 1'b1);       // bring it back
        look(16'h006E);
        chk("re-validating restores the winner", match_addr === 4'd0);
        chk("and the match count",               match_count === 5'd4);

        // ================================================================
        // The two extremes of a ternary entry.
        // ================================================================
        store_pattern(4'd15, "XXXXXXXXXXXXXXXX");    // all X
        look(16'h0000);  chk("all-X entry matches 0x0000", match[15] === 1'b1);
        look(16'hFFFF);  chk("all-X entry matches 0xFFFF", match[15] === 1'b1);
        look(16'hA5A5);  chk("all-X entry matches anything", match[15] === 1'b1);

        store_pattern(4'd14, "0000111100001111");    // fully specified
        look(16'h0F0F);  chk("exact entry matches its word",  match[14] === 1'b1);
        look(16'h0F0E);  chk("exact entry rejects a neighbour", match[14] === 1'b0);

        // The validity bit is what keeps an all-X entry from swallowing every
        // search: without it, an unprogrammed TCAM would match everything.
        store(4'd15, 16'h0000, 16'h0000, 1'b0);
        look(16'hA5A5);
        chk("retired all-X entry is silent", match[15] === 1'b0);

        // ================================================================
        // Nothing at all matches -> no hit.
        // ================================================================
        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);
        store_pattern(4'd0, "1111111111111111");
        look(16'h0000);
        chk("no match means no hit", hit === 1'b0 && match_count === 5'd0);
        chk("match lines are all clear", match === 16'h0000);

        $display("tb_tcam_spec: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
