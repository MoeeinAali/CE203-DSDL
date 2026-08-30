`include "tcam_pkg.vh"

// Lowest-index-wins priority encoder over the sixteen match lines.
//
// A TCAM can report several matches at once -- that is the normal case, not
// an error: 0110XXXX and 0X1X11X0 can both cover the same word. Something has
// to choose, and the near-universal convention is that the lower address
// wins, so more specific rules are simply stored earlier.
module priority_encoder (
    input  wire [`TCAM_ENTRIES-1:0] lines,
    output reg  [`TCAM_AW-1:0]      index,
    output wire                     any
);
    integer i;

    assign any = |lines;

    always @(*) begin
        index = {`TCAM_AW{1'b0}};
        // Walking downwards means the last assignment taken is the lowest
        // index that is set, so entry 0 has the highest priority.
        for (i = `TCAM_ENTRIES-1; i >= 0; i = i - 1)
            if (lines[i]) index = i[`TCAM_AW-1:0];
    end
endmodule
