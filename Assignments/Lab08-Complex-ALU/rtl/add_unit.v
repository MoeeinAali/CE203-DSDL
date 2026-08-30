// THE adder/subtractor of the machine, instantiated exactly once.
//
// Width is 17 bits because the same unit has to serve two very different
// jobs: adding two 8-bit components (9 bits would do) and combining two
// 16-bit partial products of a complex multiply (17 bits needed).
//
// Subtraction is not a second unit: x - y is the same adder with y inverted
// and a carry into the low bit, which is how a synthesiser implements it.
module add_unit (
    input  wire signed [16:0] x,
    input  wire signed [16:0] y,
    input  wire               sub,
    output wire signed [16:0] s
);
    assign s = sub ? (x - y) : (x + y);
endmodule
