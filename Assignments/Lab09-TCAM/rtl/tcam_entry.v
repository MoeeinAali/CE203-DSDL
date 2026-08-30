`include "tcam_pkg.vh"

// One 16-bit TCAM word: sixteen ternary cells plus a validity bit.
//
// The match line is a plain AND of every cell's agreement. Note that it is
// combinational all the way from the search word to the match line -- the
// storage is clocked, the lookup is not. That is what makes a CAM a CAM:
// every entry is compared at the same time, so a lookup costs one gate delay
// chain instead of sixteen memory reads.
module tcam_entry (
    input  wire                      Clk,
    input  wire                      RstN,

    input  wire                      we,
    input  wire [`TCAM_WIDTH-1:0]    wdata,     // value bits
    input  wire [`TCAM_WIDTH-1:0]    wmask,     // 1 = compare, 0 = X
    input  wire                      wvalid,

    input  wire [`TCAM_WIDTH-1:0]    search,
    output wire                      match,

    output wire [`TCAM_WIDTH-1:0]    q_value,   // observation ports
    output wire [`TCAM_WIDTH-1:0]    q_mask,
    output wire                      q_valid
);
    wire [`TCAM_WIDTH-1:0] agree;
    reg                    valid;

    genvar i;
    generate
        for (i = 0; i < `TCAM_WIDTH; i = i + 1) begin : g_cell
            tcam_cell u_cell (
                .Clk(Clk), .RstN(RstN), .we(we),
                .d(wdata[i]), .care(wmask[i]), .s(search[i]),
                .agree(agree[i]), .d_q(q_value[i]), .care_q(q_mask[i])
            );
        end
    endgenerate

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)   valid <= 1'b0;
        else if (we) valid <= wvalid;
    end

    assign match   = valid & (&agree);
    assign q_valid = valid;
endmodule
