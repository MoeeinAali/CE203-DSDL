module booth_multiplier #(
    parameter integer N = 8          
) (
    input  wire                  Clk,
    input  wire                  RstN,     
    input  wire                  start,
    input  wire signed [N-1:0]   Multiplicand,
    input  wire signed [N-1:0]   Multiplier,
    output wire signed [2*N-1:0] Product,
    output wire                  busy,
    output wire                  done
);
    wire load, step, count_zero;

    booth_control #(.N(N)) u_control (
        .Clk        (Clk),
        .RstN       (RstN),
        .start      (start),
        .count_zero (count_zero),
        .load       (load),
        .step       (step),
        .busy       (busy),
        .done       (done)
    );

    booth_datapath #(.N(N)) u_datapath (
        .Clk          (Clk),
        .RstN         (RstN),
        .load         (load),
        .step         (step),
        .Multiplicand (Multiplicand),
        .Multiplier   (Multiplier),
        .count        (),               
        .count_zero   (count_zero),
        .Product      (Product)
    );
endmodule
