`timescale 1ns/1ps

module tb_stack;
    localparam integer WIDTH = 4;
    localparam integer DEPTH = 8;

    reg                  Clk, RstN, Push, Pop;
    reg  [WIDTH-1:0]     Data_In;
    wire [WIDTH-1:0]     Data_Out;
    wire                 Full, Empty;

    stack #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .Clk(Clk), .RstN(RstN), .Data_In(Data_In),
        .Push(Push), .Pop(Pop),
        .Data_Out(Data_Out), .Full(Full), .Empty(Empty)
    );

    reg [WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer         ref_sp;

    integer pass, fail;
    integer i, k, iter;
    reg [WIDTH-1:0] exp_dout;
    reg             exp_full, exp_empty;

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    task automatic ref_reset;
        begin
            ref_sp = 0;
            for (i = 0; i < DEPTH; i = i + 1) ref_mem[i] = {WIDTH{1'b0}};
        end
    endtask

    task automatic step;
        input               p_push;
        input               p_pop;
        input [WIDTH-1:0]   p_din;
        input [255:0]       tag;
        begin
            @(negedge Clk);
            Push    = p_push;
            Pop     = p_pop;
            Data_In = p_din;

            @(posedge Clk);
            if (p_push && !p_pop && ref_sp < DEPTH) begin
                ref_mem[ref_sp] = p_din;
                ref_sp          = ref_sp + 1;
            end else if (p_pop && !p_push && ref_sp > 0) begin
                ref_sp = ref_sp - 1;
            end

            #1;                      
            check(tag);
        end
    endtask

    task automatic check;
        input [255:0] tag;
        begin
            exp_empty = (ref_sp == 0);
            exp_full  = (ref_sp == DEPTH);
            exp_dout  = (ref_sp == 0) ? {WIDTH{1'b0}} : ref_mem[ref_sp-1];

            if (Data_Out === exp_dout && Full === exp_full && Empty === exp_empty) begin
                pass = pass + 1;
            end else begin
                $display("FAIL [%0s] sp=%0d  got D=%h F=%b E=%b   exp D=%h F=%b E=%b",
                         tag, ref_sp, Data_Out, Full, Empty,
                         exp_dout, exp_full, exp_empty);
                fail = fail + 1;
            end
        end
    endtask

    task automatic do_reset;
        begin
            @(negedge Clk);
            Push = 0; Pop = 0; Data_In = 0;
            RstN = 1'b0;
            @(negedge Clk);
            RstN = 1'b1;
            ref_reset;
            #1;
            check("reset");
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        RstN = 1'b1; Push = 0; Pop = 0; Data_In = 0;
        ref_reset;

        do_reset;

        step(1'b0, 1'b1, 4'h0, "pop_when_empty_1");
        step(1'b0, 1'b1, 4'h0, "pop_when_empty_2");

        for (k = 0; k < DEPTH; k = k + 1)
            step(1'b1, 1'b0, k[WIDTH-1:0] + 4'h1, "fill");

        step(1'b1, 1'b0, 4'hF, "push_when_full_1");
        step(1'b1, 1'b0, 4'hE, "push_when_full_2");

        for (k = 0; k < DEPTH; k = k + 1)
            step(1'b0, 1'b1, 4'h0, "drain");

        step(1'b0, 1'b0, 4'h5, "idle_empty");

        step(1'b1, 1'b1, 4'hA, "both_at_empty");
        step(1'b1, 1'b0, 4'h3, "seed_mid");
        step(1'b1, 1'b0, 4'h7, "seed_mid");
        step(1'b1, 1'b1, 4'hC, "both_at_mid");
        step(1'b0, 1'b0, 4'h0, "idle_mid");
        for (k = 0; k < DEPTH; k = k + 1)
            step(1'b1, 1'b0, 4'h9, "refill");
        step(1'b1, 1'b1, 4'hB, "both_at_full");

        do_reset;

        step(1'b1, 1'b0, 4'h1, "int_push1");
        step(1'b1, 1'b0, 4'h2, "int_push2");
        step(1'b0, 1'b1, 4'h0, "int_pop2");  
        step(1'b1, 1'b0, 4'h3, "int_push3");
        step(1'b1, 1'b0, 4'h4, "int_push4");
        step(1'b0, 1'b1, 4'h0, "int_pop4");
        step(1'b0, 1'b1, 4'h0, "int_pop3");
        step(1'b0, 1'b1, 4'h0, "int_pop1");   
       
        do_reset;
        for (iter = 0; iter < 2000; iter = iter + 1)
            step($random, $random, $random, "random");

        $display("tb_stack: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end

    initial begin
        #500000;
        $display("FAIL: timeout");
        $fatal(1);
    end
endmodule
