module add_unit (
    input  wire signed [16:0] x,
    input  wire signed [16:0] y,
    input  wire               sub,
    output wire signed [16:0] s
);
    assign s = sub ? (x - y) : (x + y);
endmodule
