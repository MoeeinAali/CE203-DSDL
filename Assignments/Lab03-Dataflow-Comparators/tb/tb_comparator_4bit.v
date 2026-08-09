`timescale 1ns/1ps

module tb_comparator_4bit;
    reg  [3:0] A, B;
    wire       GT, EQ, LT;

    comparator_4bit dut (.A(A), .B(B), .GT(GT), .EQ(EQ), .LT(LT));

    integer ai, bi, pass, fail;
    reg exp_gt, exp_eq, exp_lt;

    initial begin
        pass = 0;
        fail = 0;
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                A = ai[3:0];
                B = bi[3:0];
                #1;
                exp_gt = (ai > bi);
                exp_eq = (ai == bi);
                exp_lt = (ai < bi);
                if (GT === exp_gt && EQ === exp_eq && LT === exp_lt)
                    pass = pass + 1;
                else begin
                    $display("FAIL A=%0d B=%0d got GEL=%b%b%b exp=%b%b%b",
                             ai, bi, GT, EQ, LT, exp_gt, exp_eq, exp_lt);
                    fail = fail + 1;
                end
            end
        end
        $display("tb_comparator_4bit: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
