// Serial bit-by-bit comparator — approach B.
// Entire module is continuous-assign only (no always, no hierarchical
// instances). State is held by a master–slave latch pair built from
// assign feedback, which behaves like a negative-edge-triggered FF:
//   * clk=1  → master samples next-state
//   * clk=0  → slave updates from master (outputs change here)
// Testbenches drive A/B while clk=1 and sample outputs after the falling
// edge, matching the FF version's "one bit per clock cycle" contract.
module serial_comparator_assign (
    input  wire clk,
    input  wire reset,   // async active-high (overrides latches)
    input  wire A,
    input  wire B,
    output wire GT,
    output wire EQ,
    output wire LT
);
    wire nclk;
    assign nclk = ~clk;

    // Slave outputs (= current state visible to next-state logic & pins).
    wire eq_q, gt_q;

    // Next-state (same equations as approach A).
    wire eq_d, gt_d;
    assign eq_d = eq_q & ~(A ^ B);
    assign gt_d = gt_q | (eq_q & A & ~B);

    // Master latches (transparent while clk=1).
    wire eq_m, gt_m;
    assign eq_m = reset ? 1'b1 : (clk  ? eq_d : eq_m);
    assign gt_m = reset ? 1'b0 : (clk  ? gt_d : gt_m);

    // Slave latches (transparent while clk=0) — capture on falling edge.
    assign eq_q = reset ? 1'b1 : (nclk ? eq_m : eq_q);
    assign gt_q = reset ? 1'b0 : (nclk ? gt_m : gt_q);

    assign EQ = eq_q;
    assign GT = gt_q;
    assign LT = ~eq_q & ~gt_q;
endmodule
