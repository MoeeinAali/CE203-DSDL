`timescale 1ns/1ps
`include "complex_pkg.vh"

// Part (b): complex multiplication.
//
// Same DUT, MUL mode. The model computes
//     (ar + j*ai)(br + j*bi) = (ar*br - ai*bi) + j(ar*bi + ai*br)
// in plain integer arithmetic and then clamps, so it shares nothing with the
// four-cycle schedule inside the design.
//
// Besides the numeric sweep this testbench pins down two structural claims:
// the multiply really costs four cycles (one per product), and the ALU is
// never asked to start a second operation while the first is running -- which
// is the whole point of having a single multiplier.
module tb_complex_mul;
    reg                 Clk = 1'b0, RstN = 1'b1;
    reg                 start = 1'b0;
    reg [1:0]           op = `ALU_MUL;
    reg [`CX_WORD-1:0]  a = 16'd0, b = 16'd0;
    wire [`CX_WORD-1:0] y;
    wire                ovf, busy, done;

    complex_alu dut (
        .Clk(Clk), .RstN(RstN), .start(start), .op(op), .a(a), .b(b),
        .y(y), .ovf(ovf), .busy(busy), .done(done)
    );

    always #5 Clk = ~Clk;

    integer pass = 0, fail = 0;
    integer cyc  = 0;
    always @(posedge Clk) cyc = cyc + 1;

    // Continuous invariant: a new operation must never be started while the
    // shared units are still busy with the previous one.
    always @(posedge Clk)
        if (RstN && start && busy) begin
            $display("  FAIL @%0t: start asserted while the ALU is busy", $time);
            fail = fail + 1;
        end

    integer i, j, k, m, n, t0, seed;
    integer ar, ai, br, bi, er, ei, raw_re, raw_im;
    reg     eovf;

    integer corner [0:8];

    function integer sat8i;
        input integer v;
        begin
            if      (v >  127) sat8i =  127;
            else if (v < -128) sat8i = -128;
            else               sat8i =  v;
        end
    endfunction

    function outside;
        input integer v;
        begin
            outside = (v > 127) || (v < -128);
        end
    endfunction

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s  a=%h b=%h y=%h (want re=%0d im=%0d)",
                         $time, name, a, b, y, er, ei);
            end
        end
    endtask

    task automatic run_mul;
        input [`CX_WORD-1:0] A;
        input [`CX_WORD-1:0] B;
        begin
            @(negedge Clk); a = A; b = B; op = `ALU_MUL; start = 1'b1;
            @(negedge Clk); start = 1'b0; t0 = cyc;
            while (!done) @(negedge Clk);
        end
    endtask

    task automatic check_pair;
        input [`CX_WORD-1:0] A;
        input [`CX_WORD-1:0] B;
        begin
            ar = $signed(A[7:0]);  ai = $signed(A[15:8]);
            br = $signed(B[7:0]);  bi = $signed(B[15:8]);

            raw_re = ar*br - ai*bi;
            raw_im = ar*bi + ai*br;
            er     = sat8i(raw_re);
            ei     = sat8i(raw_im);
            eovf   = outside(raw_re) || outside(raw_im);

            run_mul(A, B);
            chk("real part",      y[7:0]  === er[7:0]);
            chk("imaginary part", y[15:8] === ei[7:0]);
            chk("overflow flag",  ovf     === eovf);
        end
    endtask

    initial begin
        corner[0] = -128; corner[1] = -127; corner[2] = -64;
        corner[3] =   -1; corner[4] =    0; corner[5] =   1;
        corner[6] =    5; corner[7] =   11; corner[8] = 127;

        @(negedge Clk); RstN = 1'b0;
        repeat (3) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);

        // ---- worked examples ----
        // (3 + 4j)(1 - 2j) = 3 - 6j + 4j + 8 = 11 - 2j
        run_mul({8'sd4, 8'sd3}, {-8'sd2, 8'sd1});
        chk("(3+4j)(1-2j) = 11-2j", y === {-8'sd2, 8'sd11});
        // j * j = -1
        run_mul({8'sd1, 8'sd0}, {8'sd1, 8'sd0});
        chk("j*j = -1", y === {8'sd0, -8'sd1});
        // (5 + 0j)(0 + 3j) = 15j
        run_mul({8'sd0, 8'sd5}, {8'sd3, 8'sd0});
        chk("5 * 3j = 15j", y === {8'sd15, 8'sd0});
        // saturation: (100 + 0j)(0 + 100j) = 10000j -> clamped to 127j
        run_mul({8'sd0, 8'sd100}, {8'sd100, 8'sd0});
        chk("100 * 100j saturates to 127j", y === {8'sd127, 8'sd0} && ovf === 1'b1);

        // ---- latency: one cycle per real product ----
        run_mul({8'sd1, 8'sd1}, {8'sd1, 8'sd1});
        chk("multiply occupies the multiplier for 4 cycles", (cyc - t0) == 4);

        // ---- every corner combination ----
        for (i = 0; i < 9; i = i + 1)
        for (j = 0; j < 9; j = j + 1)
        for (k = 0; k < 9; k = k + 1)
        for (m = 0; m < 9; m = m + 1)
            check_pair({corner[j][7:0], corner[i][7:0]},
                       {corner[m][7:0], corner[k][7:0]});

        // ---- random sweep ----
        seed = 32'd1405;
        for (n = 0; n < 1000; n = n + 1)
            check_pair($random(seed), $random(seed));

        $display("tb_complex_mul: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
