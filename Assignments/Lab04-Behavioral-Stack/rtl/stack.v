module stack #(
    parameter integer WIDTH = 4,
    parameter integer DEPTH = 8
) (
    input  wire                  Clk,
    input  wire                  RstN,
    input  wire [WIDTH-1:0]      Data_In,
    input  wire                  Push,
    input  wire                  Pop,
    output reg  [WIDTH-1:0]      Data_Out,
    output wire                  Full,
    output wire                  Empty
);
    localparam integer PTR_W = $clog2(DEPTH) + 1;

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_W-1:0] sp;                 

    integer i;

    assign Empty = (sp == 0);
    assign Full  = (sp == DEPTH[PTR_W-1:0]);

    wire do_push = Push & ~Pop & ~Full;
    wire do_pop  = Pop  & ~Push & ~Empty;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            sp <= {PTR_W{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {WIDTH{1'b0}};
        end else begin
            if (do_push) begin
                mem[sp] <= Data_In;
                sp      <= sp + 1'b1;
            end else if (do_pop) begin
                sp <= sp - 1'b1;
            end
        end
    end

    always @(*) begin
        if (sp == 0)
            Data_Out = {WIDTH{1'b0}};
        else
            Data_Out = mem[sp - 1'b1];
    end
endmodule
