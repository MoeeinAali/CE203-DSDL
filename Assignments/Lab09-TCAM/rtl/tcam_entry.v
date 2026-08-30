`include "tcam_pkg.vh"

module tcam_entry (
    input  wire                      Clk,
    input  wire                      RstN,

    input  wire                      we,
    input  wire [`TCAM_WIDTH-1:0]    wdata,    
    input  wire [`TCAM_WIDTH-1:0]    wmask,  
    input  wire                      wvalid,

    input  wire [`TCAM_WIDTH-1:0]    search,
    output wire                      match,

    output wire [`TCAM_WIDTH-1:0]    q_value,  
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
