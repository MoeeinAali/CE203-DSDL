`ifndef COMPLEX_PKG_VH
`define COMPLEX_PKG_VH

`define CX_HALF   8      // bits per component
`define CX_WORD   16     // bits per complex value
`define CX_WIDE   17     // adder width: two 16-bit products still fit
`define IW        32     // instruction width
`define MEM_WORDS 32     // "a 32-word memory"
`define MEM_AW    5
`define REG_AW    3      // 8 complex registers

// --- opcodes ---
`define OP_NOP   4'h0
`define OP_LDI   4'h1    // rd <- imm
`define OP_MOV   4'h2    // rd <- rs
`define OP_ADD   4'h3    // rd <- rs + rt
`define OP_SUB   4'h4    // rd <- rs - rt
`define OP_MUL   4'h5    // rd <- rs * rt
`define OP_HALT  4'hF

// --- what the shared ALU is asked to do ---
`define ALU_ADD  2'd0
`define ALU_SUB  2'd1
`define ALU_MUL  2'd2

`endif
