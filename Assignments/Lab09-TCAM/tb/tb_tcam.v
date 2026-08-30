`timescale 1ns/1ps
`include "tcam_pkg.vh"

// The whole 16 x 16 TCAM against a reference model.
//
// The model is three lines of behavioural code with no cells, no priority
// encoder and no popcount tree, so it cannot repeat a structural mistake the
// design makes. It is driven with random contents AND random searches,
// because the interesting behaviour of a TCAM is what happens when stored
// patterns OVERLAP -- and overlap is exactly what a hand-written set of test
// vectors tends to avoid.
//
// One configuration is also swept over all 65536 possible search words, so at
// least one complete map of the match space is verified rather than sampled.
module tb_tcam;
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
    integer c, e, w, seed;

    // model copy of the contents
    reg [`TCAM_WIDTH-1:0] m_val  [0:`TCAM_ENTRIES-1];
    reg [`TCAM_WIDTH-1:0] m_mask [0:`TCAM_ENTRIES-1];
    reg [`TCAM_ENTRIES-1:0] m_vld;

    reg [`TCAM_ENTRIES-1:0] exp_match;
    reg [`TCAM_AW-1:0]      exp_addr;
    reg [`TCAM_CNTW-1:0]    exp_count;
    reg                     exp_hit;

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s (search=%h match=%h/%h hit=%b/%b addr=%0d/%0d cnt=%0d/%0d)",
                         $time, name, search, match, exp_match, hit, exp_hit,
                         match_addr, exp_addr, match_count, exp_count);
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
            m_val[a]  = v;
            m_mask[a] = m;
            m_vld[a]  = vld;
            #1;
        end
    endtask

    // Recompute what the TCAM should report for the current `search`.
    task automatic model;
        integer g;
        begin
            exp_match = {`TCAM_ENTRIES{1'b0}};
            exp_count = {`TCAM_CNTW{1'b0}};
            for (g = 0; g < `TCAM_ENTRIES; g = g + 1)
                if (m_vld[g] && (((search ^ m_val[g]) & m_mask[g]) == {`TCAM_WIDTH{1'b0}})) begin
                    exp_match[g] = 1'b1;
                    exp_count    = exp_count + 1'b1;
                end
            exp_hit  = |exp_match;
            exp_addr = {`TCAM_AW{1'b0}};
            for (g = `TCAM_ENTRIES-1; g >= 0; g = g - 1)
                if (exp_match[g]) exp_addr = g[`TCAM_AW-1:0];
        end
    endtask

    task automatic probe;
        input [`TCAM_WIDTH-1:0] s;
        begin
            search = s; #1;
            model;
            chk("match lines", match       === exp_match);
            chk("hit",         hit         === exp_hit);
            chk("count",       match_count === exp_count);
            // The winning address is only defined when something matched.
            if (exp_hit) chk("priority address", match_addr === exp_addr);
        end
    endtask

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);

        for (e = 0; e < `TCAM_ENTRIES; e = e + 1) begin
            m_val[e]  = 16'd0;
            m_mask[e] = 16'd0;
            m_vld[e]  = 1'b0;
        end
        #1;

        // ---- an empty TCAM must be silent, despite every cell holding X ----
        probe(16'h0000);
        probe(16'hFFFF);
        probe(16'h5A5A);
        chk("empty TCAM never hits", hit === 1'b0 && match_count === 5'd0);

        // ---- write-back check on the stored contents ----
        store(4'd7, 16'h1234, 16'hFF0F, 1'b1);
        dbg_addr = 4'd7; #1;
        chk("value stored", dbg_value === 16'h1234);
        chk("mask stored",  dbg_mask  === 16'hFF0F);
        chk("valid stored", dbg_valid === 1'b1);
        dbg_addr = 4'd6; #1;
        chk("neighbouring entry untouched", dbg_valid === 1'b0);

        // ---- random contents, random searches ----
        seed = 32'd90909;
        for (c = 0; c < 60; c = c + 1) begin
            for (e = 0; e < `TCAM_ENTRIES; e = e + 1) begin
                // Masks are biased towards having many X positions, which is
                // what makes entries overlap and the priority encoder matter.
                store(e[`TCAM_AW-1:0],
                      $random(seed),
                      {$random(seed)} & {$random(seed)},
                      (({$random(seed)} % 8) != 0));
            end
            for (w = 0; w < 200; w = w + 1)
                probe($random(seed));
        end

        // ---- one configuration swept over the entire search space ----
        for (e = 0; e < `TCAM_ENTRIES; e = e + 1)
            store(e[`TCAM_AW-1:0],
                  $random(seed),
                  {$random(seed)} & {$random(seed)},
                  1'b1);
        for (w = 0; w < 65536; w = w + 1)
            probe(w[`TCAM_WIDTH-1:0]);

        $display("tb_tcam: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
