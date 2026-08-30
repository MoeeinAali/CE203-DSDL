`include "complex_pkg.vh"

module complex_cpu (
    input  wire                    Clk,
    input  wire                    RstN,
    input  wire                    run,        // 0 = hold (used while loading)

    // program load port
    input  wire                    prog_we,
    input  wire [`MEM_AW-1:0]      prog_addr,
    input  wire [`IW-1:0]          prog_data,

    // observation
    input  wire [`REG_AW-1:0]      dbg_raddr,
    output wire [`CX_WORD-1:0]     dbg_rdata,
    output reg  [`MEM_AW-1:0]      pc,
    output reg                     halted,      // fetching has stopped
    output wire                    finished,    // ... and the pipeline is empty
    output reg                     ovf_sticky,
    output wire                    alu_busy,
    output wire                    ex_busy,
    output wire                    wb_we,
    output wire [`REG_AW-1:0]      wb_rd,
    output wire [`CX_WORD-1:0]     wb_data
);
    // ------------------------------------------------------------------ IF --
    wire [`IW-1:0] if_instr;

    imem u_imem (
        .Clk(Clk), .we(prog_we), .waddr(prog_addr), .wdata(prog_data),
        .raddr(pc), .rdata(if_instr)
    );

    // ------------------------------------------------------------- IF / ID --
    reg              id_v;
    reg [`IW-1:0]    id_ir;

    wire [3:0]            id_op  = id_ir[31:28];
    wire [`REG_AW-1:0]    id_rd  = id_ir[27:25];
    wire [`REG_AW-1:0]    id_rs  = id_ir[24:22];
    wire [`REG_AW-1:0]    id_rt  = id_ir[21:19];
    wire [`CX_WORD-1:0]   id_imm = id_ir[15:0];

    wire id_is_alu  = (id_op == `OP_ADD) || (id_op == `OP_SUB) || (id_op == `OP_MUL);
    wire id_is_halt = (id_op == `OP_HALT);
    wire id_writes  = id_is_alu || (id_op == `OP_LDI) || (id_op == `OP_MOV);
    wire id_uses_rs = id_is_alu || (id_op == `OP_MOV);
    wire id_uses_rt = id_is_alu;

    wire [1:0] id_alu_op = (id_op == `OP_SUB) ? `ALU_SUB :
                           (id_op == `OP_MUL) ? `ALU_MUL : `ALU_ADD;

    // ------------------------------------------------------------------ ID --
    wire [`CX_WORD-1:0] rf_rd1, rf_rd2;
    reg                 wb_v;
    reg [`REG_AW-1:0]   wb_a;
    reg [`CX_WORD-1:0]  wb_d;

    assign wb_we   = wb_v;
    assign wb_rd   = wb_a;
    assign wb_data = wb_d;

    regfile u_rf (
        .Clk(Clk), .RstN(RstN),
        .we(wb_v), .wa(wb_a), .wd(wb_d),
        .ra1(id_rs), .ra2(id_rt), .rd1(rf_rd1), .rd2(rf_rd2),
        .ra_dbg(dbg_raddr), .rd_dbg(dbg_rdata)
    );

    // Write-back forwarding: the register array is written on this edge, so a
    // combinational read of the same address still returns the old value.
    wire [`CX_WORD-1:0] rs_val = (wb_v && wb_a == id_rs) ? wb_d : rf_rd1;
    wire [`CX_WORD-1:0] rt_val = (wb_v && wb_a == id_rt) ? wb_d : rf_rd2;

    // ------------------------------------------------------------- ID / EX --
    reg                 ex_v;
    reg                 ex_is_alu;
    reg                 ex_writes;
    reg [`REG_AW-1:0]   ex_rd;
    reg [`CX_WORD-1:0]  ex_simple;    // result of LDI / MOV, which need no ALU

    reg                 alu_start;
    reg [1:0]           alu_op;
    reg [`CX_WORD-1:0]  alu_a, alu_b;
    wire [`CX_WORD-1:0] alu_y;
    wire                alu_done, alu_ovf;

    complex_alu u_alu (
        .Clk(Clk), .RstN(RstN),
        .start(alu_start), .op(alu_op), .a(alu_a), .b(alu_b),
        .y(alu_y), .ovf(alu_ovf), .busy(alu_busy), .done(alu_done)
    );

    assign ex_busy = ex_v;

    assign finished = halted && !ex_v && !wb_v;

    // ------------------------------------------------------------- control --
    wire ex_completing = ex_v && (!ex_is_alu || alu_done);
    wire ex_can_accept = !ex_v || ex_completing;

    wire hazard = ex_v && ex_writes &&
                  ((id_uses_rs && ex_rd == id_rs) ||
                   (id_uses_rt && ex_rd == id_rt));

    wire halting = id_v && id_is_halt && ex_can_accept;
    wire id_go   = id_v && ex_can_accept && !hazard;
    wire if_go   = !halted && !halting && (!id_v || id_go);

    // ------------------------------------------------------------ sequential --
    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            pc         <= {`MEM_AW{1'b0}};
            id_v       <= 1'b0;
            id_ir      <= {`IW{1'b0}};
            ex_v       <= 1'b0;
            ex_is_alu  <= 1'b0;
            ex_writes  <= 1'b0;
            ex_rd      <= {`REG_AW{1'b0}};
            ex_simple  <= {`CX_WORD{1'b0}};
            alu_start  <= 1'b0;
            alu_op     <= 2'd0;
            alu_a      <= {`CX_WORD{1'b0}};
            alu_b      <= {`CX_WORD{1'b0}};
            wb_v       <= 1'b0;
            wb_a       <= {`REG_AW{1'b0}};
            wb_d       <= {`CX_WORD{1'b0}};
            halted     <= 1'b0;
            ovf_sticky <= 1'b0;
        end else if (run) begin
            alu_start <= 1'b0;
            wb_v      <= 1'b0;

            // ---- EX -> WB ----
            if (ex_completing) begin
                wb_v <= ex_writes;
                wb_a <= ex_rd;
                wb_d <= ex_is_alu ? alu_y : ex_simple;
                if (ex_is_alu && alu_ovf) ovf_sticky <= 1'b1;
                ex_v <= 1'b0;
            end

            if (id_go && !id_is_halt) begin
                ex_v      <= 1'b1;
                ex_is_alu <= id_is_alu;
                ex_writes <= id_writes;
                ex_rd     <= id_rd;
                ex_simple <= (id_op == `OP_LDI) ? id_imm : rs_val;
                if (id_is_alu) begin
                    alu_start <= 1'b1;
                    alu_op    <= id_alu_op;
                    alu_a     <= rs_val;
                    alu_b     <= rt_val;
                end
            end

            // ---- IF -> ID ----
            if (halting) begin
                halted <= 1'b1;
                id_v   <= 1'b0;
            end else if (if_go) begin
                id_v  <= 1'b1;
                id_ir <= if_instr;
                pc    <= pc + 1'b1;
            end else if (id_go) begin
                id_v  <= 1'b0;
            end
        end
    end
endmodule
