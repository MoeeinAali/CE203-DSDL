module booth_control #(
    parameter integer N = 8
) (
    input  wire Clk,
    input  wire RstN,        
    input  wire start,        
    input  wire count_zero,   
    output reg  load,          
    output reg  step,        
    output wire busy,
    output wire done
);
    localparam [1:0] S_IDLE = 2'd0,
                     S_BUSY = 2'd1,
                     S_DONE = 2'd2;

    reg [1:0] state, next_state;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) state <= S_IDLE;
        else       state <= next_state;
    end

    always @(*) begin
        case (state)
            S_IDLE: next_state = start      ? S_BUSY : S_IDLE;
            S_BUSY: next_state = count_zero ? S_DONE : S_BUSY;
            S_DONE: next_state = start      ? S_BUSY : S_DONE;
            default: next_state = S_IDLE;
        endcase
    end

    always @(*) begin
        load = 1'b0;
        step = 1'b0;
        case (state)
            S_IDLE: load = start;
            S_BUSY: step = 1'b1;
            S_DONE: load = start;
            default: ;
        endcase
    end

    assign busy = (state == S_BUSY);
    assign done = (state == S_DONE);
endmodule
