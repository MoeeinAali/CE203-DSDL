`timescale 1ns/1ps
`include "complex_pkg.vh"

module tb_complex_cpu;
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
    integer i, n, prog_len, seed, guard;

    reg [`IW-1:0]      prog [0:`MEM_WORDS-1];
    reg [`CX_WORD-1:0] mreg [0:7];        // model register file
    reg                movf;              // model sticky overflow

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
        input [3:0]           o;
        input [`REG_AW-1:0]   rd;
        input [`REG_AW-1:0]   rs;
        input [`REG_AW-1:0]   rt;
        input [`CX_WORD-1:0]  imm;
        begin
            enc = {o, rd, rs, rt, 3'b000, imm};
        end
    endfunction

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

    // ---- the reference model: run the program one instruction at a time ----
    task automatic model_run;
        integer p, ar, ai, br, bi, rr, ri, rr8, ri8;
        reg [`IW-1:0]      ins;
        reg [3:0]          o;
        reg [`REG_AW-1:0]  rd, rs, rt;
        integer            g;
        begin
            for (g = 0; g < 8; g = g + 1) mreg[g] = {`CX_WORD{1'b0}};
            movf = 1'b0;
            p    = 0;
            g    = 0;
            while (p < `MEM_WORDS && g < 4*`MEM_WORDS) begin
                g   = g + 1;
                ins = prog[p];
                o   = ins[31:28];
                rd  = ins[27:25];
                rs  = ins[24:22];
                rt  = ins[21:19];

                ar = $signed(mreg[rs][7:0]);   ai = $signed(mreg[rs][15:8]);
                br = $signed(mreg[rt][7:0]);   bi = $signed(mreg[rt][15:8]);

                case (o)
                    `OP_HALT: p = `MEM_WORDS;      // stop
                    `OP_NOP:  p = p + 1;
                    `OP_LDI:  begin mreg[rd] = ins[15:0];  p = p + 1; end
                    `OP_MOV:  begin mreg[rd] = mreg[rs];   p = p + 1; end
                    `OP_ADD, `OP_SUB, `OP_MUL: begin
                        if (o == `OP_ADD) begin rr = ar + br;        ri = ai + bi;        end
                        else if (o == `OP_SUB) begin rr = ar - br;   ri = ai - bi;        end
                        else begin rr = ar*br - ai*bi;               ri = ar*bi + ai*br;  end
                        if (outside(rr) || outside(ri)) movf = 1'b1;
                        rr8 = sat8i(rr);
                        ri8 = sat8i(ri);
                        mreg[rd] = {ri8[7:0], rr8[7:0]};
                        p = p + 1;
                    end
                    default:  p = p + 1;          // unused opcode acts as NOP
                endcase
            end
        end
    endtask

    // ---- load a program, reset the pipeline, run it to completion ----
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

            run_en = 1'b1;
            c = 0;
            // `finished` (not `halted`) is the safe point to read results:
            // it also requires the last write-back to have landed.
            while (!finished && c < 4000) begin
                @(negedge Clk);
                c = c + 1;
            end
            cycles = c;
            run_en = 1'b0;
        end
    endtask

    task automatic compare_state;
        input [511:0] tag;
        integer g;
        reg [`CX_WORD-1:0] got;
        begin
            for (g = 0; g < 8; g = g + 1) begin
                dbg_raddr = g[`REG_AW-1:0]; #1; got = dbg_rdata;
                if (got !== mreg[g]) begin
                    fail = fail + 1;
                    $display("  FAIL @%0t: %0s  r%0d = %h, model says %h",
                             $time, tag, g, got, mreg[g]);
                end else pass = pass + 1;
            end
            chk("sticky overflow flag", ovf_sticky === movf);
        end
    endtask

    task automatic rd_hw;
        input  [`REG_AW-1:0]  r;
        output [`CX_WORD-1:0] v;
        begin
            dbg_raddr = r; #1; v = dbg_rdata;
        end
    endtask

    task automatic fill_halt;
        integer g;
        begin
            for (g = 0; g < `MEM_WORDS; g = g + 1)
                prog[g] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        end
    endtask

    integer cycles;
    reg [`CX_WORD-1:0] tmp;

    initial begin
        @(negedge Clk); RstN = 1'b0;
        repeat (3) @(negedge Clk); RstN = 1'b1;

        // ------------------------------------------------- a demo program --
        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd4, 8'sd3});
        prog[1] = enc(`OP_LDI, 3'd2, 3'd0, 3'd0, {-8'sd2, 8'sd1});
        prog[2] = enc(`OP_MUL, 3'd3, 3'd1, 3'd2, 16'd0);
        prog[3] = enc(`OP_ADD, 3'd4, 3'd1, 3'd2, 16'd0);
        prog[4] = enc(`OP_SUB, 3'd5, 3'd3, 3'd4, 16'd0);
        prog[5] = enc(`OP_MUL, 3'd6, 3'd5, 3'd1, 16'd0);
        prog[6] = enc(`OP_MOV, 3'd7, 3'd6, 3'd0, 16'd0);
        prog[7] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);

        model_run;
        hw_run(cycles);
        chk("demo program halted", halted === 1'b1);
        compare_state("demo program");
        rd_hw(3'd3, tmp); chk("demo: r3 = 11 - 2j", tmp === {-8'sd2, 8'sd11});
        rd_hw(3'd5, tmp); chk("demo: r5 =  7 - 4j", tmp === {-8'sd4, 8'sd7});
        rd_hw(3'd6, tmp); chk("demo: r6 = 37 + 16j", tmp === {8'sd16, 8'sd37});
        $display("  demo program: %0d instructions in %0d cycles", 8, cycles);

        // ------------------- a dependency chain: every result feeds the next --
        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd1, 8'sd2});
        prog[1] = enc(`OP_LDI, 3'd2, 3'd0, 3'd0, {8'sd1, 8'sd1});
        prog[2] = enc(`OP_ADD, 3'd3, 3'd1, 3'd2, 16'd0);
        prog[3] = enc(`OP_ADD, 3'd3, 3'd3, 3'd2, 16'd0);
        prog[4] = enc(`OP_ADD, 3'd3, 3'd3, 3'd2, 16'd0);
        prog[5] = enc(`OP_MUL, 3'd3, 3'd3, 3'd2, 16'd0);
        prog[6] = enc(`OP_SUB, 3'd3, 3'd3, 3'd1, 16'd0);
        prog[7] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        model_run;
        hw_run(cycles);
        chk("chain program halted", halted === 1'b1);
        compare_state("back-to-back dependency chain");

        // ------------------------------- saturation propagates through a program --
        fill_halt;
        prog[0] = enc(`OP_LDI, 3'd1, 3'd0, 3'd0, {8'sd100, 8'sd100});
        prog[1] = enc(`OP_LDI, 3'd2, 3'd0, 3'd0, {8'sd100, 8'sd100});
        prog[2] = enc(`OP_ADD, 3'd3, 3'd1, 3'd2, 16'd0);
        prog[3] = enc(`OP_MUL, 3'd4, 3'd1, 3'd2, 16'd0);
        prog[4] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);
        model_run;
        hw_run(cycles);
        compare_state("saturating program");
        chk("overflow was reported", ovf_sticky === 1'b1);

        // ------------------------------------------------ random programs --
        seed = 32'd8080;
        for (n = 0; n < 150; n = n + 1) begin
            fill_halt;
            prog_len = 4 + ({$random(seed)} % 20);
            for (i = 0; i < prog_len; i = i + 1) begin
                case ({$random(seed)} % 8)
                    0, 1: prog[i] = enc(`OP_LDI, ({$random(seed)} % 8), 3'd0, 3'd0,
                                        $random(seed));
                    2:    prog[i] = enc(`OP_MOV, ({$random(seed)} % 8),
                                        ({$random(seed)} % 8), 3'd0, 16'd0);
                    3:    prog[i] = enc(`OP_NOP, 3'd0, 3'd0, 3'd0, 16'd0);
                    4, 5: prog[i] = enc(`OP_ADD, ({$random(seed)} % 8),
                                        ({$random(seed)} % 8), ({$random(seed)} % 8), 16'd0);
                    6:    prog[i] = enc(`OP_SUB, ({$random(seed)} % 8),
                                        ({$random(seed)} % 8), ({$random(seed)} % 8), 16'd0);
                    7:    prog[i] = enc(`OP_MUL, ({$random(seed)} % 8),
                                        ({$random(seed)} % 8), ({$random(seed)} % 8), 16'd0);
                endcase
            end
            prog[prog_len] = enc(`OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0);

            model_run;
            hw_run(cycles);
            chk("random program halted", halted === 1'b1);
            compare_state("random program");
        end

        $display("tb_complex_cpu: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
