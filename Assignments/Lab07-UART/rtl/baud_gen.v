module baud_gen #(
    parameter integer DIVISOR = 16
) (
    input  wire Clk,
    input  wire RstN,
    output wire tick
);
    reg [15:0] cnt;

    assign tick = (cnt == DIVISOR[15:0] - 16'd1);

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)     cnt <= 16'd0;
        else if (tick) cnt <= 16'd0;
        else           cnt <= cnt + 16'd1;
    end
endmodule
