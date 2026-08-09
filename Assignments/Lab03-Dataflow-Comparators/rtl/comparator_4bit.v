// 4-bit combinational comparator built hierarchically from four
// cascadable 1-bit stages (MSB → LSB). Pure structural + dataflow leaves.
module comparator_4bit (
    input  wire [3:0] A,
    input  wire [3:0] B,
    output wire       GT,
    output wire       EQ,
    output wire       LT
);
    wire gt3, eq3, lt3;
    wire gt2, eq2, lt2;
    wire gt1, eq1, lt1;

    // Seed: "equal so far" before looking at any bit.
    cascadable_1bit_comparator u3 (
        .A(A[3]), .B(B[3]),
        .GT_in(1'b0), .EQ_in(1'b1), .LT_in(1'b0),
        .GT_out(gt3), .EQ_out(eq3), .LT_out(lt3)
    );
    cascadable_1bit_comparator u2 (
        .A(A[2]), .B(B[2]),
        .GT_in(gt3), .EQ_in(eq3), .LT_in(lt3),
        .GT_out(gt2), .EQ_out(eq2), .LT_out(lt2)
    );
    cascadable_1bit_comparator u1 (
        .A(A[1]), .B(B[1]),
        .GT_in(gt2), .EQ_in(eq2), .LT_in(lt2),
        .GT_out(gt1), .EQ_out(eq1), .LT_out(lt1)
    );
    cascadable_1bit_comparator u0 (
        .A(A[0]), .B(B[0]),
        .GT_in(gt1), .EQ_in(eq1), .LT_in(lt1),
        .GT_out(GT), .EQ_out(EQ), .LT_out(LT)
    );
endmodule
