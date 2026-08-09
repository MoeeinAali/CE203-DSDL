// Serial bit-by-bit comparator — approach A.
// Next-state logic is pure dataflow (assign); state is held in edge-
// triggered flip-flops (always @(posedge clk or posedge reset)).
// Bits arrive MSB-first on A/B each clock; outputs reflect the comparison
// of all bits seen so far (including the bit sampled on this edge).
module serial_comparator_ff (
    input  wire clk,
    input  wire reset,   // async active-high
    input  wire A,
    input  wire B,
    output wire GT,
    output wire EQ,
    output wire LT
);
    // State: eq_q=1 means "equal so far"; gt_q=1 means "A>B decided".
    // Encoding after reset: (eq_q, gt_q) = (1, 0)  → EQ
    //                        (0, 1)                 → GT
    //                        (0, 0)                 → LT
    reg eq_q, gt_q;

    wire eq_d, gt_d;

    // Next-state (combinational dataflow):
    // Stay equal only while still equal AND current bits match.
    assign eq_d = eq_q & ~(A ^ B);
    // Become/stay greater if already greater, OR still equal and A>B this bit.
    assign gt_d = gt_q | (eq_q & A & ~B);
    // LT is implied: ~eq_d & ~gt_d

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            eq_q <= 1'b1;
            gt_q <= 1'b0;
        end else begin
            eq_q <= eq_d;
            gt_q <= gt_d;
        end
    end

    assign EQ = eq_q;
    assign GT = gt_q;
    assign LT = ~eq_q & ~gt_q;
endmodule
