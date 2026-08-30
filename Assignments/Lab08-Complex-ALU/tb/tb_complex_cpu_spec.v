`timescale 1ns/1ps
`include "complex_pkg.vh"

module tb_complex_cpu_spec;
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

    integer pass = 0, fail = 0;
    integer i, writes, cyc_ldi, cyc_mul_indep, cyc_mul_dep, cyc_nop;
    reg [`IW-1:0] prog [0:`MEM_WORDS-1];
    reg [`CX_WORD-1:0] tmp;

    integer wcount = 0;
    always @(posedge Clk) if (run_en && wb_we) wcount = wcount + 1;

    always @(posedge Clk)
        if (RstN && run_en && alu_busy && !ex_busy) begin
            $display("  FAIL @%0t: the ALU is running with no instruction in EX", $time);
            fail = fail + 1;
        end

    task automatic chk;
        input [511:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s", $time, name);
            end
        end
    endtask

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

    task automatic fill_halt;
        integer g;
        begin
            for (g = 0; g < `MEM_WORDS; g = g + 1)
                prog[g] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        end
    endtask

    task automatic hw_run;
        output integer cycles;
        integer c;
        begin
            run_en = 1'b0;
            @(negedge Clk);
            for (c = 0; c < `MEM_WORDS; c = c + 1) begin
                prog_we = 1'b1; prog_addr = c[`MEM_AW-1:0]; prog_data = prog[c];
                @(negedge Clk);
            end
            prog_we = 1'b0;

            RstN = 1'b0; @(negedge Clk); @(negedge Clk); RstN = 1'b1;
            @(negedge Clk);

            wcount = 0;
            run_en = 1'b1;
            c = 0;
            while (!finished && c < 4000) begin
                @(negedge Clk);
                c = c + 1;
            end
            cycles = c;
            run_en = 1'b0;
        end
    endtask

    task automatic rd_hw;
        input  [`REG_AW-1:0]  r;
        output [`CX_WORD-1:0] v;
        begin
            dbg_raddr = r; #1; v = dbg_rdata;
        end
    endtask

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (3) @(negedge Clk); RstN = 1'b1;

        fill_halt;
        for (i = 0; i < 16; i = i + 1)
            prog[i] = enc(`OP_LDI, i[2:0], 3'd0, 3'd0, {8'd0, i[7:0]});
        prog[16] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        hw_run(cyc_ldi);
        $display("  16 independent single-cycle instructions: %0d cycles", cyc_ldi);
        chk("independent instructions overlap", cyc_ldi < 2*16);
        chk("all 16 results were written",      wcount == 16);
        rd_hw(3'd7, tmp);
        chk("last LDI landed", tmp === {8'd0, 8'd15});

        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd1, 8'sd2});
        prog[1] = enc(`OP_LDI, 3'd2, 3'd0, 3'd0, {8'sd1, 8'sd1});
        for (i = 0; i < 16; i = i + 1)
            prog[2+i] = enc(`OP_MUL, 3'd3 + (i % 5), 3'd1, 3'd2, 16'd0);
        prog[18] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        hw_run(cyc_mul_indep);
        $display("  16 independent multiplies:                %0d cycles", cyc_mul_indep);
        chk("multiplies are limited by the shared multiplier", cyc_mul_indep > 4*16);
        chk("all 18 results were written",                     wcount == 18);

        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd0, 8'sd1});
        prog[1] = enc(`OP_LDI, 3'd2, 3'd0, 3'd0, {8'sd1, 8'sd1});
        for (i = 0; i < 16; i = i + 1)
            prog[2+i] = enc(`OP_MUL, 3'd2, 3'd2, 3'd1, 16'd0);
        prog[18] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        hw_run(cyc_mul_dep);
        $display("  16 dependent multiplies:                  %0d cycles", cyc_mul_dep);
        chk("a dependency chain costs more than independent work",
            cyc_mul_dep > cyc_mul_indep);
        $display("  cost of the interlock: %0d cycles over %0d dependent pairs",
                 cyc_mul_dep - cyc_mul_indep, 15);
        chk("the interlock costs exactly one cycle per dependent pair",
            (cyc_mul_dep - cyc_mul_indep) == 15);
        rd_hw(3'd2, tmp);
        chk("x * 1 repeated 16 times is still x", tmp === {8'sd1, 8'sd1});

        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd7, 8'sd7});
        for (i = 1; i < 12; i = i + 1)
            prog[i] = enc(`OP_NOP, 3'd0, 3'd0, 3'd0, 16'd0);
        prog[12] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        hw_run(cyc_nop);
        chk("a NOP writes no register", wcount == 1);
        rd_hw(3'd1, tmp);
        chk("the LDI before the NOPs still landed", tmp === {8'sd7, 8'sd7});

        fill_halt;
        prog[0] = enc(`OP_LDI,  3'd1, 3'd0, 3'd0, {8'sd3, 8'sd3});
        prog[1] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        prog[2] = enc(`OP_LDI,  3'd2, 3'd0, 3'd0, {8'sd9, 8'sd9});
        prog[3] = enc(`OP_LDI,  3'd3, 3'd0, 3'd0, {8'sd9, 8'sd9});
        hw_run(i);
        chk("machine halted",                halted === 1'b1);
        chk("only the instruction before HALT wrote", wcount == 1);
        rd_hw(3'd1, tmp); chk("r1 was written",          tmp === {8'sd3, 8'sd3});
        rd_hw(3'd2, tmp); chk("r2 after HALT untouched", tmp === 16'd0);
        rd_hw(3'd3, tmp); chk("r3 after HALT untouched", tmp === 16'd0);

        writes = pc;
        repeat (10) @(negedge Clk);
        chk("PC frozen after HALT", pc === writes[`MEM_AW-1:0]);

        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd0, 8'sd3});   // 3
        prog[1] = enc(`OP_ADD, 3'd1, 3'd1, 3'd1, 16'd0);            // 6
        prog[2] = enc(`OP_ADD, 3'd1, 3'd1, 3'd1, 16'd0);            // 12
        prog[3] = enc(`OP_MUL, 3'd1, 3'd1, 3'd1, 16'd0);            // 144 -> clamps
        prog[4] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        hw_run(i);
        rd_hw(3'd1, tmp);
        chk("rd used as both sources reads the old value",
            tmp === {8'sd0, 8'sd127});
        chk("the clamp was reported", ovf_sticky === 1'b1);

        $display("tb_complex_cpu_spec: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
