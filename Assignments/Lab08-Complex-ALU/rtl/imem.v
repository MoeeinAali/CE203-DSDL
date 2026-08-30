`include "complex_pkg.vh"

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
