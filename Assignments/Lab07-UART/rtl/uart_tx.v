`include "uart_pkg.vh"

module uart_tx #(
    parameter ODD_PARITY = 1'b0
) (
    input  wire                        Clk,
    input  wire                        RstN,
    input  wire                        os_tick,     
    input  wire                        tx_start,   
    input  wire [`UART_DATA_BITS-1:0]  tx_data,   
    output reg                         txd,      
    output wire                        tx_busy,
    output reg                         tx_done   
);
    localparam [2:0] IDLE   = 3'd0,
                     START  = 3'd1,
                     PARITY = 3'd2,
                     DATA   = 3'd3,
                     STOP   = 3'd4;

    reg [2:0]                      st;
    reg [3:0]                      os;  
    reg [2:0]                      idx;  
    reg [`UART_DATA_BITS-1:0]      sh;  
    reg                            par;

    wire par_of_data = ODD_PARITY ? ~(^tx_data) : (^tx_data);

    wire bit_end = os_tick && (os == `UART_OVERSAMPLE - 1);

    assign tx_busy = (st != IDLE);

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            st      <= IDLE;
            os      <= 4'd0;
            idx     <= 3'd0;
            sh      <= {`UART_DATA_BITS{1'b0}};
            par     <= 1'b0;
            txd     <= 1'b1;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            if (st != IDLE && os_tick)
                os <= bit_end ? 4'd0 : os + 4'd1;

            case (st)
                IDLE: begin
                    txd <= 1'b1;
                    if (tx_start) begin
                        sh  <= tx_data;
                        par <= par_of_data;
                        txd <= 1'b0;         
                        os  <= 4'd0;
                        idx <= `UART_DATA_BITS - 1;
                        st  <= START;
                    end
                end

                START: if (bit_end) begin
                    txd <= par;
                    st  <= PARITY;
                end

                PARITY: if (bit_end) begin
                    txd <= sh[`UART_DATA_BITS-1];
                    sh  <= {sh[`UART_DATA_BITS-2:0], 1'b0};
                    st  <= DATA;
                end

                DATA: if (bit_end) begin
                    if (idx == 3'd0) begin
                        txd <= 1'b1;         
                        st  <= STOP;
                    end else begin
                        txd <= sh[`UART_DATA_BITS-1];
                        sh  <= {sh[`UART_DATA_BITS-2:0], 1'b0};
                        idx <= idx - 3'd1;
                    end
                end

                STOP: if (bit_end) begin
                    txd     <= 1'b1;     
                    tx_done <= 1'b1;
                    st      <= IDLE;
                end

                default: st <= IDLE;
            endcase
        end
    end
endmodule
