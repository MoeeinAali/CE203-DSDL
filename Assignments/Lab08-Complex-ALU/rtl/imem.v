`include "complex_pkg.vh"

// The 32-word memory the lab sheet specifies, holding the program.
//
// The write port is how a program gets in: on a board it would be driven by a
// small loader (or replaced by a ROM initialised at synthesis time); in the
// testbenches it is driven directly while the pipeline is held with run = 0.
// Reading is combinational so the fetch stage can register the instruction on
// the same edge it advances the program counter.
//
// The program counter is 5 bits and simply wraps from word 31 back to word 0,
// so a program with no HALT in it runs for ever rather than falling off the
// end. Every program in the testbenches fills unused words with HALT, which is
// the sane convention for a memory this small.
module imem (
    input  wire                    Clk,
    input  wire                    we,
    input  wire [`MEM_AW-1:0]      waddr,
    input  wire [`IW-1:0]          wdata,
    input  wire [`MEM_AW-1:0]      raddr,
    output wire [`IW-1:0]          rdata
);
    reg [`IW-1:0] mem [0:`MEM_WORDS-1];

    always @(posedge Clk) if (we) mem[waddr] <= wdata;

    assign rdata = mem[raddr];
endmodule
