`timescale 1ns/1ps
`include "complex_pkg.vh"

// Presentation waveform: the demo program running through the pipeline.
//
//   r1 = 3 + 4j
//   r2 = 1 - 2j
//   r3 = r1 * r2  = 11 - 2j
//   r4 = r1 + r2  =  4 + 2j
//   r5 = r3 - r4  =  7 - 4j
//   r6 = r5 * r1  = 37 + 16j
//   r7 = r6
//   halt
`ifndef VCD_FILE
`define VCD_FILE "waves/complex_cpu.vcd"
`endif

module tb_complex_wave;
    reg                 Clk = 1'b0, RstN = 1'b1, run_en = 1'b0;
    reg                 prog_we = 1'b0;
    reg [`MEM_AW-1:0]   prog_addr = 5'd0;
    reg [`IW-1:0]       prog_data = 32'd0;
    reg [`REG_AW-1:0]   dbg_raddr = 3'd0;

    wire [`CX_WORD-1:0] dbg_rdata;
    wire [`MEM_AW-1:0]  pc;
    wire                halted, finished, ovf_sticky, alu_busy, ex_busy, wb_we;
    wire [`REG_AW-1:0]  wb_rd;
    wire [`CX_WORD-1:0] wb_data;

    complex_cpu dut (
        .Clk(Clk), .RstN(RstN), .run(run_en),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
        .dbg_raddr(dbg_raddr), .dbg_rdata(dbg_rdata),
        .pc(pc), .halted(halted), .finished(finished), .ovf_sticky(ovf_sticky),
        .alu_busy(alu_busy), .ex_busy(ex_busy),
        .wb_we(wb_we), .wb_rd(wb_rd), .wb_data(wb_data)
    );

    always #5 Clk = ~Clk;

    reg [`IW-1:0] prog [0:`MEM_WORDS-1];
    integer i;

    function [`IW-1:0] enc;
        input [3:0]          o;
        input [`REG_AW-1:0]  rd;
        input [`REG_AW-1:0]  rs;
        input [`REG_AW-1:0]  rt;
        input [`CX_WORD-1:0] imm;
        begin
            enc = {o, rd, rs, rt, 3'b000, imm};
        end
    endfunction

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_complex_wave);

        for (i = 0; i < `MEM_WORDS; i = i + 1)
            prog[i] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);

        prog[0] = enc(`OP_LDI,  3'd1, 3'd0, 3'd0, {8'sd4, 8'sd3});
        prog[1] = enc(`OP_LDI,  3'd2, 3'd0, 3'd0, {-8'sd2, 8'sd1});
        prog[2] = enc(`OP_MUL,  3'd3, 3'd1, 3'd2, 16'd0);
        prog[3] = enc(`OP_ADD,  3'd4, 3'd1, 3'd2, 16'd0);
        prog[4] = enc(`OP_SUB,  3'd5, 3'd3, 3'd4, 16'd0);
        prog[5] = enc(`OP_MUL,  3'd6, 3'd5, 3'd1, 16'd0);
        prog[6] = enc(`OP_MOV,  3'd7, 3'd6, 3'd0, 16'd0);
        prog[7] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);

        @(negedge Clk); RstN = 1'b0;
        repeat (3) @(negedge Clk); RstN = 1'b1;

        // Only the words the program actually reaches are loaded, so the
        // picture is not dominated by the loader.
        for (i = 0; i < 8; i = i + 1) begin
            prog_we = 1'b1; prog_addr = i[`MEM_AW-1:0]; prog_data = prog[i];
            @(negedge Clk);
        end
        prog_we = 1'b0;

        RstN = 1'b0; @(negedge Clk); @(negedge Clk); RstN = 1'b1;
        @(negedge Clk);

        run_en = 1'b1;
        i = 0;
        while (!finished && i < 200) begin
            @(negedge Clk);
            i = i + 1;
        end
        repeat (6) @(negedge Clk);

        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
