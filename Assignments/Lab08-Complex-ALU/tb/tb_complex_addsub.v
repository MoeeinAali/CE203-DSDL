`timescale 1ns/1ps
`include "complex_pkg.vh"

// Part (a): complex addition and subtraction.
//
// The DUT is complex_alu in its ADD / SUB modes. Results are compared against
// a model written in plain integer arithmetic -- no shift registers, no state
// machine, nothing the design and the model could get wrong together.
//
// Coverage: every combination of nine corner values on each of the four
// components (both operations), plus a random sweep, plus a check that the
// operation really takes the number of cycles the schedule promises.
module tb_complex_addsub;
    reg                 Clk = 1'b0, RstN = 1'b1;
    reg                 start = 1'b0;
    reg [1:0]           op = 2'd0;
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

    integer i, j, k, m, n, t0, seed;
    integer ar, ai, br, bi, er, ei;
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
                $display("  FAIL @%0t: %0s  op=%0d a=%h b=%h y=%h (want re=%0d im=%0d)",
                         $time, name, op, a, b, y, er, ei);
            end
        end
    endtask

    // Drive one operation and return with y valid.
    task automatic run_op;
        input [1:0]           o;
        input [`CX_WORD-1:0]  A;
        input [`CX_WORD-1:0]  B;
        begin
            @(negedge Clk); op = o; a = A; b = B; start = 1'b1;
            @(negedge Clk); start = 1'b0; t0 = cyc;
            while (!done) @(negedge Clk);
        end
    endtask

    // Model + compare for one operand pair.
    task automatic check_pair;
        input [1:0]          o;
        input [`CX_WORD-1:0] A;
        input [`CX_WORD-1:0] B;
        begin
            ar = $signed(A[7:0]);  ai = $signed(A[15:8]);
            br = $signed(B[7:0]);  bi = $signed(B[15:8]);

            if (o == `ALU_SUB) begin
                er = sat8i(ar - br);  ei = sat8i(ai - bi);
                eovf = outside(ar - br) || outside(ai - bi);
            end else begin
                er = sat8i(ar + br);  ei = sat8i(ai + bi);
                eovf = outside(ar + br) || outside(ai + bi);
            end

            run_op(o, A, B);
            chk("real part",      y[7:0]  === er[7:0]);
            chk("imaginary part", y[15:8] === ei[7:0]);
            chk("overflow flag",  ovf     === eovf);
        end
    endtask

    initial begin
        corner[0] = -128; corner[1] = -127; corner[2] = -64;
        corner[3] =   -1; corner[4] =    0; corner[5] =   1;
        corner[6] =    5; corner[7] =   64; corner[8] = 127;

        @(negedge Clk); RstN = 1'b0;
        repeat (3) @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);

        chk("idle after reset", busy === 1'b0 && done === 1'b0);

        // ---- a worked example, so the report has something concrete ----
        // (3 + 4j) + (-1 + 2j) = (2 + 6j)
        run_op(`ALU_ADD, {8'sd4, 8'sd3}, {8'sd2, -8'sd1});
        chk("(3+4j)+(-1+2j) = 2+6j", y === {8'sd6, 8'sd2});
        // (3 + 4j) - (-1 + 2j) = (4 + 2j)
        run_op(`ALU_SUB, {8'sd4, 8'sd3}, {8'sd2, -8'sd1});
        chk("(3+4j)-(-1+2j) = 4+2j", y === {8'sd2, 8'sd4});

        // ---- latency: exactly two passes through the shared adder ----
        run_op(`ALU_ADD, {8'sd1, 8'sd1}, {8'sd1, 8'sd1});
        chk("add occupies the adder for 2 cycles", (cyc - t0) == 2);
        run_op(`ALU_SUB, {8'sd1, 8'sd1}, {8'sd1, 8'sd1});
        chk("sub occupies the adder for 2 cycles", (cyc - t0) == 2);

        // ---- every corner combination, both operations ----
        for (i = 0; i < 9; i = i + 1)
        for (j = 0; j < 9; j = j + 1)
        for (k = 0; k < 9; k = k + 1)
        for (m = 0; m < 9; m = m + 1) begin
            check_pair(`ALU_ADD, {corner[j][7:0], corner[i][7:0]},
                                 {corner[m][7:0], corner[k][7:0]});
            check_pair(`ALU_SUB, {corner[j][7:0], corner[i][7:0]},
                                 {corner[m][7:0], corner[k][7:0]});
        end

        // ---- random sweep ----
        seed = 32'd20260826;
        for (n = 0; n < 1000; n = n + 1) begin
            check_pair(n[0] ? `ALU_SUB : `ALU_ADD,
                       $random(seed), $random(seed));
        end

        $display("tb_complex_addsub: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
