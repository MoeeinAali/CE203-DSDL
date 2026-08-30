// One ternary bit: two flip-flops and a three-gate comparator.
//
// This is the whole idea of a TCAM in miniature. `care` decides whether the
// position takes part in the comparison at all; when it is 0 the cell agrees
// with anything, which is the stored symbol X.
module tcam_cell (
    input  wire Clk,
    input  wire RstN,
    input  wire we,        // write this cell
    input  wire d,         // value to store
    input  wire care,      // 1 = compare, 0 = store X
    input  wire s,         // search bit
    output wire agree,     // this position does not object to s
    output wire d_q,       // stored value  (observation)
    output wire care_q     // stored care   (observation)
);
    reg vq, cq;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            vq <= 1'b0;
            cq <= 1'b0;      // reset stores X, hence the validity bit above it
        end else if (we) begin
            vq <= d;
            cq <= care;
        end
    end

    assign agree  = ~cq | ~(vq ^ s);
    assign d_q    = vq;
    assign care_q = cq;
endmodule
