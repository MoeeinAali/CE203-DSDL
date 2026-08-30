// Shared parameters for the ternary content addressable memory.
//
// What "ternary" means here
// -------------------------
// An ordinary CAM stores 0 and 1. A TCAM stores a third symbol, X, meaning
// "do not compare this position". Hardware has no third logic level to store,
// so each bit is kept as TWO flip-flops:
//
//     value  the 0 or 1 to compare against
//     care   1 = compare this position, 0 = the position is X
//
// A stored bit therefore encodes the three symbols the lab sheet uses:
//
//     care=1, value=0  ->  0
//     care=1, value=1  ->  1
//     care=0           ->  X   (value is irrelevant)
//
// and one bit position "agrees" with the search word when
//
//     agree = ~care | ~(value ^ search)
//
// An entry matches when every one of its bit positions agrees AND the entry
// is valid. The validity bit is not optional decoration: an entry whose care
// bits are all zero is all-X, and all-X matches EVERY search word. After
// reset the care bits are zero, so without a validity bit an empty TCAM would
// report sixteen matches for any input.
`ifndef TCAM_PKG_VH
`define TCAM_PKG_VH

`define TCAM_WIDTH    16    // bits per entry
`define TCAM_ENTRIES  16    // "16 registers of 16 bits"
`define TCAM_AW       4     // address of one entry
`define TCAM_CNTW     5     // 0 .. 16 matches

`endif
