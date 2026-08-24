`timescale 1ns/1ps

// Two things this testbench establishes that the main one does not:
//
//   1. The design is genuinely parameterised in N (4, 8 and 16 bit
//      instances all multiply correctly), so nothing is hard-coded to 8.
//   2. The radix-4 iteration count really is N/2 and not N — i.e. the
//      "shift more than one bit per clock" requirement of the lab is met.
//      The cycle count is MEASURED from the DUT, not asserted.
module tb_booth_param;

    integer pass, fail;

    // ---------------- N = 4 ----------------
    reg                Clk4, RstN4, start4;
    reg  signed [3:0]  a4, b4;
    wire signed [7:0]  p4;
    wire               busy4, done4;
    booth_multiplier #(.N(4)) dut4 (
        .Clk(Clk4), .RstN(RstN4), .start(start4),
        .Multiplicand(a4), .Multiplier(b4),
        .Product(p4), .busy(busy4), .done(done4));
    initial Clk4 = 0;
    always #5 Clk4 = ~Clk4;

    // ---------------- N = 8 ----------------
    reg                Clk8, RstN8, start8;
    reg  signed [7:0]  a8, b8;
    wire signed [15:0] p8;
    wire               busy8, done8;
    booth_multiplier #(.N(8)) dut8 (
        .Clk(Clk8), .RstN(RstN8), .start(start8),
        .Multiplicand(a8), .Multiplier(b8),
        .Product(p8), .busy(busy8), .done(done8));
    initial Clk8 = 0;
    always #5 Clk8 = ~Clk8;

    // ---------------- N = 16 ----------------
    reg                 Clk16, RstN16, start16;
    reg  signed [15:0]  a16, b16;
    wire signed [31:0]  p16;
    wire                busy16, done16;
    booth_multiplier #(.N(16)) dut16 (
        .Clk(Clk16), .RstN(RstN16), .start(start16),
        .Multiplicand(a16), .Multiplier(b16),
        .Product(p16), .busy(busy16), .done(done16));
    initial Clk16 = 0;
    always #5 Clk16 = ~Clk16;

    integer cyc4, cyc8, cyc16;
    integer i, j;

    // NOTE: a bit part-select such as i[7:0] is UNSIGNED in Verilog, so
    // `i[7:0] * j[7:0]` silently computes an unsigned product. The reference
    // must be formed from signed regs for the comparison to mean anything.
    reg signed [3:0]   sa4,  sb4;
    reg signed [7:0]   sa8,  sb8;
    reg signed [15:0]  sa16, sb16;
    reg signed [7:0]   exp4;
    reg signed [15:0]  exp8;
    reg signed [31:0]  exp16;

    task automatic report;
        input [255:0] tag;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                $display("FAIL [%0s]", tag);
                fail = fail + 1;
            end
        end
    endtask

    // --- N=4 : exhaustive over all signed 4-bit pairs ---
    task automatic run4;
        begin
            @(negedge Clk4); RstN4 = 0; start4 = 0; a4 = 0; b4 = 0;
            @(negedge Clk4); RstN4 = 1;
            for (i = -8; i <= 7; i = i + 1) begin
                for (j = -8; j <= 7; j = j + 1) begin
                    @(negedge Clk4);
                    sa4 = i[3:0]; sb4 = j[3:0]; exp4 = sa4 * sb4;
                    a4 = sa4; b4 = sb4; start4 = 1;
                    @(negedge Clk4); start4 = 0;
                    // Count clock edges from the one that sampled `start`
                    // until `done` is observed high.
                    cyc4 = 0;
                    while (!done4) begin
                        @(posedge Clk4); #1; cyc4 = cyc4 + 1;
                    end
                    #1;
                    report("N4/product", p4 === exp4);
                end
            end
            // 4-bit radix-4 => 2 iterations => 2+1 = 3 clocks to done
            report("N4/cycles", cyc4 == (4/2) + 1);
            $display("  N=4  : %0d clocks per multiply (radix-2 would need %0d)",
                     cyc4, 4 + 1);
        end
    endtask

    // --- N=8 : sampled pairs incl. the most-negative value ---
    task automatic run8;
        begin
            @(negedge Clk8); RstN8 = 0; start8 = 0; a8 = 0; b8 = 0;
            @(negedge Clk8); RstN8 = 1;
            for (i = -128; i <= 127; i = i + 17) begin
                for (j = -128; j <= 127; j = j + 13) begin
                    @(negedge Clk8);
                    sa8 = i[7:0]; sb8 = j[7:0]; exp8 = sa8 * sb8;
                    a8 = sa8; b8 = sb8; start8 = 1;
                    @(negedge Clk8); start8 = 0;
                    cyc8 = 0;
                    while (!done8) begin
                        @(posedge Clk8); #1; cyc8 = cyc8 + 1;
                    end
                    #1;
                    report("N8/product", p8 === exp8);
                end
            end
            report("N8/cycles", cyc8 == (8/2) + 1);
            $display("  N=8  : %0d clocks per multiply (radix-2 would need %0d)",
                     cyc8, 8 + 1);
        end
    endtask

    // --- N=16 : sampled pairs, incl. -32768 ---
    task automatic run16;
        begin
            @(negedge Clk16); RstN16 = 0; start16 = 0; a16 = 0; b16 = 0;
            @(negedge Clk16); RstN16 = 1;
            for (i = -32768; i <= 32767; i = i + 4447) begin
                for (j = -32768; j <= 32767; j = j + 5119) begin
                    @(negedge Clk16);
                    sa16 = i[15:0]; sb16 = j[15:0]; exp16 = sa16 * sb16;
                    a16 = sa16; b16 = sb16; start16 = 1;
                    @(negedge Clk16); start16 = 0;
                    cyc16 = 0;
                    while (!done16) begin
                        @(posedge Clk16); #1; cyc16 = cyc16 + 1;
                    end
                    #1;
                    report("N16/product", p16 === exp16);
                end
            end
            report("N16/cycles", cyc16 == (16/2) + 1);
            $display("  N=16 : %0d clocks per multiply (radix-2 would need %0d)",
                     cyc16, 16 + 1);
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        RstN4 = 1; RstN8 = 1; RstN16 = 1;
        start4 = 0; start8 = 0; start16 = 0;
        $display("measured iteration counts:");
        run4;
        run8;
        run16;
        $display("tb_booth_param: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
