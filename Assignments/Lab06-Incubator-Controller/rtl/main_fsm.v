`include "incubator_pkg.vh"

module main_fsm (
    input  wire               Clk,
    input  wire               RstN,      
    input  wire               tick,      
    input  wire signed [7:0]  temp,      
    output wire               heater,     
    output wire               cooler,     
    output wire [1:0]         state,      
    output wire               cooler_next  
);
    localparam [1:0] S1 = 2'd0,  
                     S2 = 2'd1,  
                     S3 = 2'd2;  

    reg [1:0] cur, nxt;

    assign state  = cur;
    assign heater = (cur == S3);
    assign cooler = (cur == S2);

    assign cooler_next = (nxt == S2);

    always @(*) begin
        nxt = cur;                    
        case (cur)
            S1: begin
                if (temp > `TH_COOL_ON)       nxt = S2; 
                else if (temp < `TH_HEAT_ON)  nxt = S3; 
            end
            S2: if (temp < `TH_COOL_OFF)      nxt = S1;  
            S3: if (temp > `TH_HEAT_OFF)      nxt = S1;  
            default:                          nxt = S1;
        endcase
    end

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)     cur <= S1;
        else if (tick) cur <= nxt;
    end
endmodule
