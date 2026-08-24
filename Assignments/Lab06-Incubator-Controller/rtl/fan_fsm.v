`include "incubator_pkg.vh"

module fan_fsm (
    input  wire               Clk,
    input  wire               RstN,     
    input  wire               tick,     
    input  wire signed [7:0]  temp,
    input  wire               enable,  

    output wire [3:0]         crs,      
    output wire [1:0]         state   
);
    localparam [1:0] OUT  = 2'd0, 
                     F_S1 = 2'd1, 
                     F_S2 = 2'd2, 
                     F_S3 = 2'd3; 

    reg [1:0] cur, nxt;

    assign state = cur;

    assign crs = (cur == F_S1) ? `CRS_4 :
                 (cur == F_S2) ? `CRS_6 :
                 (cur == F_S3) ? `CRS_8 : `CRS_OFF;

    always @(*) begin
        nxt = cur;                      
        case (cur)
            OUT:  if (temp > `TH_FAN_IN)    nxt = F_S1;  
            F_S1: begin
                if      (temp > `TH_FAN_UP1) nxt = F_S2; 
                else if (temp < `TH_FAN_OUT) nxt = OUT;  
            end
            F_S2: begin
                if      (temp > `TH_FAN_UP2)   nxt = F_S3; 
                else if (temp < `TH_FAN_DOWN1) nxt = F_S1; 
            end
            F_S3: if (temp < `TH_FAN_DOWN2)  nxt = F_S2;
            default:                         nxt = OUT;
        endcase
    end

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)       cur <= OUT;
        else if (!enable) cur <= OUT;   
        else if (tick)    cur <= nxt;
    end
endmodule
