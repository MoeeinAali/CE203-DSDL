`include "uart_pkg.vh"

module uart_rx #(
    parameter ODD_PARITY = 1'b0
) (
    input  wire                          Clk,
    input  wire                          RstN,
    input  wire                          os_tick,
    input  wire                          rxd,          

    output reg  [`UART_RX_REG_BITS-1:0]  rx_reg,      
    output wire [`UART_DATA_BITS-1:0]    rx_data,    
    output reg                           rx_valid,    
    output reg                           parity_err,
    output reg                           frame_err,
    output wire                          rx_busy
);
    localparam integer OS = `UART_OVERSAMPLE;

    localparam [2:0] IDLE  = 3'd0,
                     START = 3'd1,
                     RECV  = 3'd2,
                     STOP  = 3'd3,
                     RESYN = 3'd4;   

    reg  rx_s0, rx_s1;
    always @(posedge Clk or negedge RstN) begin
        if (!RstN) {rx_s0, rx_s1} <= 2'b11;
        else       {rx_s0, rx_s1} <= {rxd, rx_s0};
    end

    reg [2:0]                        st;
    reg [3:0]                        os;
    reg [2:0]                        nbit;
    reg [`UART_RX_REG_BITS-1:0]      sh;

    assign rx_data = rx_reg[`UART_DATA_BITS-1:0];
    assign rx_busy = (st != IDLE);

    wire exp_par = ODD_PARITY ? ~(^sh[`UART_DATA_BITS-1:0]) : (^sh[`UART_DATA_BITS-1:0]);

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            st         <= IDLE;
            os         <= 4'd0;
            nbit       <= 3'd0;
            sh         <= {`UART_RX_REG_BITS{1'b0}};
            rx_reg     <= {`UART_RX_REG_BITS{1'b0}};
            rx_valid   <= 1'b0;
            parity_err <= 1'b0;
            frame_err  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (st)
                IDLE: if (!rx_s1) begin      
                    os <= 4'd0;
                    st <= START;
                end

                START: if (os_tick) begin
                    if (os == OS/2 - 1) begin
                        if (rx_s1) begin
                            st <= IDLE;    
                        end else begin
                            os   <= 4'd0;
                            nbit <= 3'd0;
                            st   <= RECV;
                        end
                    end else begin
                        os <= os + 4'd1;
                    end
                end

                RECV: if (os_tick) begin
                    if (os == OS-1) begin
                        os   <= 4'd0;
                        sh   <= {sh[`UART_RX_REG_BITS-2:0], rx_s1};
                        nbit <= nbit + 3'd1;
                        if (nbit == `UART_RX_REG_BITS - 1) st <= STOP;
                    end else begin
                        os <= os + 4'd1;
                    end
                end

                STOP: if (os_tick) begin
                    if (os == OS-1) begin
                        os         <= 4'd0;
                        rx_reg     <= sh;
                        parity_err <= (sh[`UART_RX_REG_BITS-1] != exp_par);
                        frame_err  <= ~rx_s1;      
                        rx_valid   <= 1'b1;
                        st         <= rx_s1 ? IDLE : RESYN;
                    end else begin
                        os <= os + 4'd1;
                    end
                end

                RESYN: if (rx_s1) st <= IDLE;

                default: st <= IDLE;
            endcase
        end
    end
endmodule
