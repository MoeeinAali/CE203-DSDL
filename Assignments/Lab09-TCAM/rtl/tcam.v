`include "tcam_pkg.vh"

module tcam (
    input  wire                       Clk,
    input  wire                       RstN,

    input  wire                       we,
    input  wire [`TCAM_AW-1:0]        waddr,
    input  wire [`TCAM_WIDTH-1:0]     wdata,
    input  wire [`TCAM_WIDTH-1:0]     wmask,
    input  wire                       wvalid,

    input  wire [`TCAM_WIDTH-1:0]     search,
    output wire [`TCAM_ENTRIES-1:0]   match,
    output wire                       hit,
    output wire [`TCAM_AW-1:0]        match_addr,
    output wire [`TCAM_CNTW-1:0]      match_count,

    // observation
    input  wire [`TCAM_AW-1:0]        dbg_addr,
    output wire [`TCAM_WIDTH-1:0]     dbg_value,
    output wire [`TCAM_WIDTH-1:0]     dbg_mask,
    output wire                       dbg_valid
);
    wire [`TCAM_WIDTH-1:0] q_value [0:`TCAM_ENTRIES-1];
    wire [`TCAM_WIDTH-1:0] q_mask  [0:`TCAM_ENTRIES-1];
    wire [`TCAM_ENTRIES-1:0] q_valid;

    genvar e;
    generate
        for (e = 0; e < `TCAM_ENTRIES; e = e + 1) begin : g_entry
            tcam_entry u_entry (
                .Clk(Clk), .RstN(RstN),
                .we(we && (waddr == e[`TCAM_AW-1:0])),
                .wdata(wdata), .wmask(wmask), .wvalid(wvalid),
                .search(search), .match(match[e]),
                .q_value(q_value[e]), .q_mask(q_mask[e]), .q_valid(q_valid[e])
            );
        end
    endgenerate

    priority_encoder u_pri (
        .lines(match), .index(match_addr), .any(hit)
    );

    // Population count of the match lines.
    integer k;
    reg [`TCAM_CNTW-1:0] cnt;
    always @(*) begin
        cnt = {`TCAM_CNTW{1'b0}};
        for (k = 0; k < `TCAM_ENTRIES; k = k + 1)
            cnt = cnt + match[k];
    end
    assign match_count = cnt;

    assign dbg_value = q_value[dbg_addr];
    assign dbg_mask  = q_mask[dbg_addr];
    assign dbg_valid = q_valid[dbg_addr];
endmodule
