module mul_unit (
    input  wire signed [7:0]  x,
    input  wire signed [7:0]  y,
    output wire signed [15:0] p
);
    assign p = x * y;
endmodule
