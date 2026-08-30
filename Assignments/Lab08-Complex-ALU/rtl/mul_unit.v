// THE multiplier of the machine.
//
// The lab sheet allows a single adder and a single multiplier in the whole
// design, so this module is instantiated exactly once -- inside complex_alu --
// and every product the machine ever computes passes through it, one per
// clock cycle.
module mul_unit (
    input  wire signed [7:0]  x,
    input  wire signed [7:0]  y,
    output wire signed [15:0] p
);
    assign p = x * y;
endmodule
