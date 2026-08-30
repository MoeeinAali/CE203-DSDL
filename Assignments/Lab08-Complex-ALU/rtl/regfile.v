`include "complex_pkg.vh"

// Eight complex registers. Two read ports feed the decode stage; the third is
// a read-only observation port used by the testbenches and the waveform, so
// they never have to reach inside the module.
//
// Reads are combinational and a write lands on the clock edge, so an
// instruction reading a register in the same cycle it is written sees the OLD
// value. The pipeline compensates for that with an explicit forward from the
// write-back stage rather than a read-during-write trick inside the array,
// which keeps this module trivially synthesisable as block RAM or flops.
module regfile (
    input  wire                    Clk,
    input  wire                    RstN,

    input  wire                    we,
    input  wire [`REG_AW-1:0]      wa,
    input  wire [`CX_WORD-1:0]     wd,

    input  wire [`REG_AW-1:0]      ra1,
    input  wire [`REG_AW-1:0]      ra2,
    output wire [`CX_WORD-1:0]     rd1,
    output wire [`CX_WORD-1:0]     rd2,

    input  wire [`REG_AW-1:0]      ra_dbg,
    output wire [`CX_WORD-1:0]     rd_dbg
);
    localparam integer NREG = (1 << `REG_AW);

    reg [`CX_WORD-1:0] r [0:NREG-1];
    integer i;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) for (i = 0; i < NREG; i = i + 1) r[i] <= {`CX_WORD{1'b0}};
        else if (we) r[wa] <= wd;
    end

    assign rd1    = r[ra1];
    assign rd2    = r[ra2];
    assign rd_dbg = r[ra_dbg];
endmodule
