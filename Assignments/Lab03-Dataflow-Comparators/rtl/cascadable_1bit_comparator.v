// Cascadable 1-bit comparator — pure dataflow (assign only).
// Cascade direction: MSB → LSB. Seed the MSB stage with (GT,EQ,LT)=(0,1,0).
module cascadable_1bit_comparator (
    input  wire A,
    input  wire B,
    input  wire GT_in,
    input  wire EQ_in,
    input  wire LT_in,
    output wire GT_out,
    output wire EQ_out,
    output wire LT_out
);
    // Still equal only if already equal AND current bits match.
    assign EQ_out = EQ_in & ~(A ^ B);

    // Greater if already greater, OR still equal and A=1,B=0.
    assign GT_out = GT_in | (EQ_in & A & ~B);

    // Less if already less, OR still equal and A=0,B=1.
    assign LT_out = LT_in | (EQ_in & ~A & B);
endmodule
