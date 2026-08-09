`timescale 1ns/1ps

module tb_cascadable_1bit;
    reg A, B, GT_in, EQ_in, LT_in;
    wire GT_out, EQ_out, LT_out;

    cascadable_1bit_comparator dut (
        .A(A), .B(B),
        .GT_in(GT_in), .EQ_in(EQ_in), .LT_in(LT_in),
        .GT_out(GT_out), .EQ_out(EQ_out), .LT_out(LT_out)
    );

    integer i, pass, fail;
    reg exp_gt, exp_eq, exp_lt;

    initial begin
        pass = 0;
        fail = 0;
        for (i = 0; i < 32; i = i + 1) begin
            {A, B, GT_in, EQ_in, LT_in} = i[4:0];
            #1;

            exp_eq = EQ_in & ~(A ^ B);
            exp_gt = GT_in | (EQ_in & A & ~B);
            exp_lt = LT_in | (EQ_in & ~A & B);

            if (GT_out === exp_gt && EQ_out === exp_eq && LT_out === exp_lt)
                pass = pass + 1;
            else begin
                $display("FAIL i=%0d A=%b B=%b in(G,E,L)=%b%b%b got=%b%b%b exp=%b%b%b",
                         i, A, B, GT_in, EQ_in, LT_in,
                         GT_out, EQ_out, LT_out, exp_gt, exp_eq, exp_lt);
                fail = fail + 1;
            end
        end
        $display("tb_cascadable_1bit: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
