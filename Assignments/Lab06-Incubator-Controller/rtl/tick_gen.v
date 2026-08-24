// Once-per-minute sample strobe.
//
// The lab specifies that the temperature is read from the sensor once every
// minute. Rather than bury a fixed constant in the design, the divider ratio
// is a parameter: synthesis uses the real value (e.g. 50 MHz x 60 s =
// 3_000_000_000, or a smaller number if the board clock is divided first),
// while simulation overrides it with a tiny value so a testbench does not
// have to simulate minutes of wall-clock time.
//
// `tick` is a single-clock-wide pulse, so the FSMs advance exactly one step
// per sample period.
module tick_gen #(
    parameter integer DIVIDE = 60_000_000   // clocks between samples
) (
    input  wire Clk,
    input  wire RstN,      // async, active-low
    output reg  tick
);
    localparam integer CNT_W = (DIVIDE <= 1) ? 1 : $clog2(DIVIDE);

    reg [CNT_W-1:0] cnt;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            cnt  <= {CNT_W{1'b0}};
            tick <= 1'b0;
        end else if (cnt == DIVIDE - 1) begin
            cnt  <= {CNT_W{1'b0}};
            tick <= 1'b1;                 // one clock wide
        end else begin
            cnt  <= cnt + 1'b1;
            tick <= 1'b0;
        end
    end
endmodule
