`include "tcam_pkg.vh"

module priority_encoder (
    input  wire [`TCAM_ENTRIES-1:0] lines,
    output reg  [`TCAM_AW-1:0]      index,
    output wire                     any
);
    integer i;

    assign any = |lines;

    always @(*) begin
        index = {`TCAM_AW{1'b0}};
        for (i = `TCAM_ENTRIES-1; i >= 0; i = i - 1)
            if (lines[i]) index = i[`TCAM_AW-1:0];
    end
endmodule
