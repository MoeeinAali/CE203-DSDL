`timescale 1ns/1ps

// Self-checking testbench for the radix-4 Booth multiplier.
//
// The reference is Verilog's own signed `*` operator, so the test proves the
// Booth recoding + arithmetic shift produce exactly the textbook product
// over the ENTIRE signed input space (all 256x256 = 65536 pairs).
module tb_booth_multiplier;
    localparam integer N = 8;

    reg                   Clk, RstN, start;
    reg  signed [N-1:0]   Multiplicand, Multiplier;
    wire signed [2*N-1:0] Product;
    wire                  busy, done;

    booth_multiplier #(.N(N)) dut (
        .Clk(Clk), .RstN(RstN), .start(start),
        .Multiplicand(Multiplicand), .Multiplier(Multiplier),
        .Product(Product), .busy(busy), .done(done)
    );

    integer pass, fail;
    integer ai, bi;
    integer cycles, max_cycles, min_cycles;
    reg signed [2*N-1:0] expected;
    // Signed holders: a part-select like ai[N-1:0] is unsigned in Verilog,
    // so the loop values must pass through signed regs before being used
    // either as stimulus or inside the `a * b` reference below.
    reg signed [N-1:0]   sa, sb;

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    // Drive one multiplication and wait for `done`, counting the clocks it
    // actually took so the speed-up claim can be measured, not assumed.
    task automatic multiply;
        input signed [N-1:0] a;
        input signed [N-1:0] b;
        begin
            @(negedge Clk);
            Multiplicand = a;
            Multiplier   = b;
            start        = 1'b1;
            @(negedge Clk);
            start = 1'b0;

            // Latency = clock edges from the one that sampled `start`
            // until `done` is observed high.
            cycles = 0;
            while (!done) begin
                @(posedge Clk); #1;
                cycles = cycles + 1;
                if (cycles > 100) begin
                    $display("FAIL: timeout waiting for done (a=%0d b=%0d)", a, b);
                    $fatal(1);
                end
            end
            #1;
        end
    endtask

    task automatic check;
        input signed [N-1:0] a;
        input signed [N-1:0] b;
        begin
            multiply(a, b);
            expected = a * b;
            if (Product === expected) begin
                pass = pass + 1;
            end else begin
                $display("FAIL a=%0d b=%0d  got=%0d (%h)  exp=%0d (%h)",
                         a, b, Product, Product, expected, expected);
                fail = fail + 1;
            end
            if (cycles > max_cycles) max_cycles = cycles;
            if (cycles < min_cycles) min_cycles = cycles;
        end
    endtask

    task automatic do_reset;
        begin
            @(negedge Clk);
            start = 1'b0; Multiplicand = 0; Multiplier = 0;
            RstN = 1'b0;
            @(negedge Clk);
            RstN = 1'b1;
            #1;
            if (busy !== 1'b0 || done !== 1'b0) begin
                $display("FAIL: flags not clear after reset (busy=%b done=%b)",
                         busy, done);
                fail = fail + 1;
            end else pass = pass + 1;
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        max_cycles = 0; min_cycles = 1000;
        RstN = 1'b1; start = 0; Multiplicand = 0; Multiplier = 0;

        do_reset;

        // --- directed corner cases (the ones Booth classically gets wrong) --
        check(  0,   0);
        check(  0,  57);
        check( 57,   0);
        check(  1,   1);
        check(  1,  -1);
        check( -1,   1);
        check( -1,  -1);
        check(127, 127);   // largest positives
        check(127,-128);
        check(-128,127);
        check(-128,-128);  // most negative squared: needs the guard bit
        check(-128,   1);
        check(  1,-128);
        check(-128,  -1);
        check( -1,-128);
        check( 85, -86);   // alternating bit patterns 0x55 / 0xAA
        check(-86,  85);
        check( 85,  85);
        check(-86, -86);

        // --- back-to-back starts without an intervening reset --------------
        check( 12,  10);
        check(-12,  10);
        check( 12, -10);
        check(-12, -10);

        // --- reset in the middle of a multiplication -----------------------
        @(negedge Clk);
        Multiplicand = 100; Multiplier = 100; start = 1'b1;
        @(negedge Clk); start = 1'b0;
        @(posedge Clk);          // let it get part-way through
        @(posedge Clk);
        do_reset;
        check(6, 7);             // must still work correctly afterwards

        // --- EXHAUSTIVE: every signed 8x8 pair -----------------------------
        for (ai = -128; ai <= 127; ai = ai + 1)
            for (bi = -128; bi <= 127; bi = bi + 1) begin
                sa = ai[N-1:0];
                sb = bi[N-1:0];
                check(sa, sb);
            end

        $display("cycles per multiply: min=%0d max=%0d (N=%0d, radix-4 => %0d iterations)",
                 min_cycles, max_cycles, N, N/2);
        $display("tb_booth_multiplier: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
