// Shared definitions for the complex-number machine.
//
// Number representation
// --------------------
// A complex value is a pair of 8-bit SIGNED two's-complement components packed
// into one 16-bit word:
//
//     word = { imag[7:0], real[7:0] }        range of each part: -128 .. +127
//
// Results are SATURATED, not wrapped: a component that leaves the range is
// clamped to -128 or +127 and a flag is raised. For a machine whose whole job
// is arithmetic on measured quantities this is the useful behaviour -- a value
// that is too large should read as "very large", not silently change sign.
//
// Instruction word (32 bits, one memory word)
// -------------------------------------------
//     [31:28] opcode
//     [27:25] rd
//     [24:22] rs
//     [21:19] rt
//     [18:16] unused
//     [15:0]  immediate, itself a complex word { imag, real }
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
