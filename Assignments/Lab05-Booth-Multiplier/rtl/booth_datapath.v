module booth_datapath #(
    parameter integer N = 8             
) (
    input  wire                  Clk,
    input  wire                  RstN,     
    input  wire                  load,      
    input  wire                  step,     
    input  wire signed [N-1:0]   Multiplicand,
    input  wire signed [N-1:0]   Multiplier,
    output wire [$clog2(N/2):0]  count,     
    output wire                  count_zero, 
    output wire signed [2*N-1:0] Product
);
    localparam integer ITER   = N / 2;          
    localparam integer CNT_W  = $clog2(N/2) + 1;
    reg signed [N+1:0]   A;     
    reg        [N-1:0]   Q;      
    reg                  Q_1;  
    reg signed [N-1:0]   M;    
    reg        [CNT_W-1:0] cnt; 

    assign count      = cnt;
    assign count_zero = (cnt == 0);
    assign Product = {A[N-1:0], Q};
    wire [2:0] booth_window = {Q[1], Q[0], Q_1};
    wire signed [N+1:0] M_ext  = {{2{M[N-1]}}, M};  
    wire signed [N+1:0] M2_ext = {M[N-1], M, 1'b0};  
    reg signed [N+1:0] addend;
    always @(*) begin
        case (booth_window)
            3'b000, 3'b111: addend =  {(N+2){1'b0}}; 
            3'b001, 3'b010: addend =  M_ext;       
            3'b011:         addend =  M2_ext;      
            3'b100:         addend = -M2_ext;       
            3'b101, 3'b110: addend = -M_ext;        
            default:        addend =  {(N+2){1'b0}};
        endcase
    end

    wire signed [N+1:0] A_sum = A + addend;
    wire signed [N+1:0] A_next  = {A_sum[N+1], A_sum[N+1], A_sum[N+1:2]};
    wire       [N-1:0] Q_next  = {A_sum[1:0], Q[N-1:2]};
    wire               Q_1_next = Q[1];

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            A   <= {(N+2){1'b0}};
            Q   <= {N{1'b0}};
            Q_1 <= 1'b0;
            M   <= {N{1'b0}};
            cnt <= {CNT_W{1'b0}};
        end else if (load) begin
            A   <= {(N+2){1'b0}};
            Q   <= Multiplier;
            Q_1 <= 1'b0;
            M   <= Multiplicand;
            cnt <= ITER[CNT_W-1:0];
        end else if (step && cnt != 0) begin
            A   <= A_next;
            Q   <= Q_next;
            Q_1 <= Q_1_next;
            cnt <= cnt - 1'b1;
        end
    end
endmodule
