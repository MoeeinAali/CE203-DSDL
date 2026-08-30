`timescale 1ns/1ps
`include "tcam_pkg.vh"

// Presentation waveform.
//
// The six patterns from the lab sheet are written into entries 0..5, then a
// series of search words is applied. The point of the picture is that one
// search word can light up several match lines at once, that the priority
// encoder picks the lowest of them, and that retiring an entry immediately
// promotes the next one.
`ifndef VCD_FILE
`define VCD_FILE "waves/tcam.vcd"
`endif

module tb_tcam_wave;
    reg                      Clk = 1'b0, RstN = 1'b1;
    reg                      we = 1'b0, wvalid = 1'b1;
    reg [`TCAM_AW-1:0]       waddr = 4'd0;
    reg [`TCAM_WIDTH-1:0]    wdata = 16'd0, wmask = 16'd0;
    reg [`TCAM_WIDTH-1:0]    search = 16'd0;
    reg [`TCAM_AW-1:0]       dbg_addr = 4'd0;

    wire [`TCAM_ENTRIES-1:0] match_lines;
    wire                     hit;
    wire [`TCAM_AW-1:0]      match_addr;
    wire [`TCAM_CNTW-1:0]    match_count;

    tcam dut (
        .Clk(Clk), .RstN(RstN),
        .we(we), .waddr(waddr), .wdata(wdata), .wmask(wmask), .wvalid(wvalid),
        .search(search), .match(match_lines), .hit(hit),
        .match_addr(match_addr), .match_count(match_count),
        .dbg_addr(dbg_addr), .dbg_value(), .dbg_mask(), .dbg_valid()
    );

    always #5 Clk = ~Clk;

    task automatic store;
        input [`TCAM_AW-1:0]    a;
        input [`TCAM_WIDTH-1:0] v;
        input [`TCAM_WIDTH-1:0] m;
        input                   vld;
        begin
            @(negedge Clk);
            waddr = a; wdata = v; wmask = m; wvalid = vld; we = 1'b1;
            @(negedge Clk); we = 1'b0;
        end
    endtask

    task automatic look;
        input [`TCAM_WIDTH-1:0] s;
        begin
            @(negedge Clk); search = s;
            repeat (3) @(negedge Clk);
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_tcam_wave);

        @(negedge Clk); RstN = 1'b0;
        repeat (2) @(negedge Clk); RstN = 1'b1;

        // the sheet's patterns, high byte marked X throughout
        store(4'd0, 16'h0068, 16'h0078, 1'b1);   // X1101XXX
        store(4'd1, 16'h002C, 16'h00AD, 1'b1);   // 0X1X11X0
        store(4'd2, 16'h0060, 16'h00F0, 1'b1);   // 0110XXXX
        store(4'd3, 16'h0080, 16'h0080, 1'b1);   // 1XXXXXXX
        store(4'd4, 16'h006F, 16'h00FF, 1'b1);   // 01101111
        store(4'd5, 16'h006E, 16'h00FF, 1'b1);   // 01101110

        look(16'h006E);      // the sheet's data word: entries 0,1,2,5 match
        look(16'h006F);      // one bit away:          entries 0,2,4 match
        look(16'h0080);      // only the 1XXXXXXX rule
        look(16'h0011);      // nothing matches at all

        store(4'd0, 16'h0068, 16'h0078, 1'b0);   // retire the winner
        look(16'h006E);      // entry 1 is promoted

        store(4'd0, 16'h0068, 16'h0078, 1'b1);   // bring it back
        look(16'h006E);

        repeat (4) @(negedge Clk);
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
