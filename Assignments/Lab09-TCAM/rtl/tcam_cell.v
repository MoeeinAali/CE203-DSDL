module tcam_cell (
    input  wire Clk,
    input  wire RstN,
    input  wire we,      
    input  wire d,       
    input  wire care,    
    input  wire s,       
    output wire agree,   
    output wire d_q,    
    output wire care_q    
);
    reg vq, cq;

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            vq <= 1'b0;
            cq <= 1'b0;   
        end else if (we) begin
            vq <= d;
            cq <= care;
        end
    end

    assign agree  = ~cq | ~(vq ^ s);
    assign d_q    = vq;
    assign care_q = cq;
endmodule
