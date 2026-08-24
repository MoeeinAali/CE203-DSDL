`timescale 1ns/1ps

module tb_stack_param;

    integer pass, fail;

`define MAKE_CASE(NAME, W, D)                                                 \
    reg                Clk``NAME, RstN``NAME, Push``NAME, Pop``NAME;          \
    reg  [W-1:0]       Din``NAME;                                             \
    wire [W-1:0]       Dout``NAME;                                            \
    wire               Full``NAME, Empty``NAME;                               \
    stack #(.WIDTH(W), .DEPTH(D)) dut``NAME (                                 \
        .Clk(Clk``NAME), .RstN(RstN``NAME), .Data_In(Din``NAME),              \
        .Push(Push``NAME), .Pop(Pop``NAME), .Data_Out(Dout``NAME),            \
        .Full(Full``NAME), .Empty(Empty``NAME));                              \
    initial Clk``NAME = 1'b0;                                                 \
    always #5 Clk``NAME = ~Clk``NAME;

    `MAKE_CASE(A, 4, 8)    
    `MAKE_CASE(B, 8, 4)   
    `MAKE_CASE(C, 2, 16)   

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

    integer k;

    task automatic run_A;
        begin
            @(negedge ClkA); RstNA = 0; PushA = 0; PopA = 0; DinA = 0;
            @(negedge ClkA); RstNA = 1; #1;
            report("A/empty_after_reset", EmptyA === 1'b1 && FullA === 1'b0);

            for (k = 0; k < 8; k = k + 1) begin
                @(negedge ClkA); PushA = 1; PopA = 0; DinA = k[3:0];
                @(posedge ClkA); #1;
                report("A/fill_flags",
                       EmptyA === 1'b0 && FullA === ((k == 7) ? 1'b1 : 1'b0)
                       && DoutA === k[3:0]);
            end
            @(negedge ClkA); PushA = 1; DinA = 4'hF;
            @(posedge ClkA); #1;
            report("A/overflow_ignored", FullA === 1'b1 && DoutA === 4'd7);

            for (k = 7; k >= 0; k = k - 1) begin
                @(negedge ClkA); PushA = 0; PopA = 1;
                @(posedge ClkA); #1;
                report("A/drain_lifo",
                       (k == 0) ? (EmptyA === 1'b1 && DoutA === 4'h0)
                                : (DoutA === (k[3:0] - 4'h1) && EmptyA === 1'b0));
            end
            @(negedge ClkA); PopA = 1;
            @(posedge ClkA); #1;
            report("A/underflow_ignored", EmptyA === 1'b1 && DoutA === 4'h0);
            @(negedge ClkA); PopA = 0;
        end
    endtask

    task automatic run_B;
        begin
            @(negedge ClkB); RstNB = 0; PushB = 0; PopB = 0; DinB = 0;
            @(negedge ClkB); RstNB = 1; #1;
            report("B/empty_after_reset", EmptyB === 1'b1 && FullB === 1'b0);

            for (k = 0; k < 4; k = k + 1) begin
                @(negedge ClkB); PushB = 1; PopB = 0; DinB = 8'hA0 + k[7:0];
                @(posedge ClkB); #1;
                report("B/fill_flags",
                       FullB === ((k == 3) ? 1'b1 : 1'b0)
                       && DoutB === (8'hA0 + k[7:0]));
            end
            @(negedge ClkB); PushB = 1; DinB = 8'hFF;
            @(posedge ClkB); #1;
            report("B/overflow_ignored", FullB === 1'b1 && DoutB === 8'hA3);

            for (k = 3; k >= 0; k = k - 1) begin
                @(negedge ClkB); PushB = 0; PopB = 1;
                @(posedge ClkB); #1;
                report("B/drain_lifo",
                       (k == 0) ? (EmptyB === 1'b1)
                                : (DoutB === (8'hA0 + k[7:0] - 8'h1)));
            end
            @(negedge ClkB); PopB = 0;
        end
    endtask

    task automatic run_C;
        begin
            @(negedge ClkC); RstNC = 0; PushC = 0; PopC = 0; DinC = 0;
            @(negedge ClkC); RstNC = 1; #1;
            report("C/empty_after_reset", EmptyC === 1'b1 && FullC === 1'b0);

            for (k = 0; k < 16; k = k + 1) begin
                @(negedge ClkC); PushC = 1; PopC = 0; DinC = k[1:0];
                @(posedge ClkC); #1;
                report("C/fill_flags",
                       FullC === ((k == 15) ? 1'b1 : 1'b0) && DoutC === k[1:0]);
            end
            @(negedge ClkC); PushC = 1; DinC = 2'b11;
            @(posedge ClkC); #1;
            report("C/overflow_ignored", FullC === 1'b1 && DoutC === 2'b11);

            for (k = 15; k >= 0; k = k - 1) begin
                @(negedge ClkC); PushC = 0; PopC = 1;
                @(posedge ClkC); #1;
                report("C/drain_lifo",
                       (k == 0) ? (EmptyC === 1'b1)
                                : (DoutC === (k[1:0] - 2'b01)));
            end
            @(negedge ClkC); PopC = 0;
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        run_A;
        run_B;
        run_C;
        $display("Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
