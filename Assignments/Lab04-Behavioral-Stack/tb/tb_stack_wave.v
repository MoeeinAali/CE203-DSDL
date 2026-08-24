`timescale 1ns/1ps

`ifndef VCD_FILE
`define VCD_FILE "waves/stack.vcd"
`endif

module tb_stack_wave;
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

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    integer k;

    task automatic step;
        input             p_push;
        input             p_pop;
        input [WIDTH-1:0] p_din;
        begin
            @(negedge Clk);
            Push = p_push; Pop = p_pop; Data_In = p_din;
            @(posedge Clk);
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_stack_wave);

        RstN = 1'b1; Push = 0; Pop = 0; Data_In = 0;

        @(negedge Clk); RstN = 1'b0;
        @(negedge Clk); RstN = 1'b1;

        step(1'b0, 1'b1, 4'h0);         
        for (k = 1; k <= DEPTH; k = k + 1) 
            step(1'b1, 1'b0, k[WIDTH-1:0]);
        step(1'b1, 1'b0, 4'hF);           
        for (k = 0; k < DEPTH; k = k + 1) 
            step(1'b0, 1'b1, 4'h0);
        step(1'b0, 1'b1, 4'h0);           
        step(1'b0, 1'b0, 4'h0);          

        @(negedge Clk);
        Push = 0; Pop = 0;
        #10;
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
