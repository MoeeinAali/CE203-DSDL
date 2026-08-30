`include "uart_pkg.vh"

module uart_link #(
    parameter integer A_OS_DIVISOR = 16,
    parameter integer B_OS_DIVISOR = 16,
    parameter         ODD_PARITY   = 1'b0
) (
    input  wire                          Clk,
    input  wire                          RstN,

    // unit A
    input  wire                          a_tx_start,
    input  wire [`UART_DATA_BITS-1:0]    a_tx_data,
    output wire                          a_tx_busy,
    output wire                          a_tx_done,
    output wire [`UART_RX_REG_BITS-1:0]  a_rx_reg,
    output wire [`UART_DATA_BITS-1:0]    a_rx_data,
    output wire                          a_rx_valid,
    output wire                          a_parity_err,
    output wire                          a_frame_err,

    // unit B
    input  wire                          b_tx_start,
    input  wire [`UART_DATA_BITS-1:0]    b_tx_data,
    output wire                          b_tx_busy,
    output wire                          b_tx_done,
    output wire [`UART_RX_REG_BITS-1:0]  b_rx_reg,
    output wire [`UART_DATA_BITS-1:0]    b_rx_data,
    output wire                          b_rx_valid,
    output wire                          b_parity_err,
    output wire                          b_frame_err,

    output wire                          a_to_b,
    output wire                          b_to_a
);
    uart #(.OS_DIVISOR(A_OS_DIVISOR), .ODD_PARITY(ODD_PARITY)) u_a (
        .Clk(Clk), .RstN(RstN),
        .tx_start(a_tx_start), .tx_data(a_tx_data),
        .txd(a_to_b), .tx_busy(a_tx_busy), .tx_done(a_tx_done),
        .rxd(b_to_a),
        .rx_reg(a_rx_reg), .rx_data(a_rx_data), .rx_valid(a_rx_valid),
        .parity_err(a_parity_err), .frame_err(a_frame_err),
        .rx_busy(), .os_tick()
    );

    uart #(.OS_DIVISOR(B_OS_DIVISOR), .ODD_PARITY(ODD_PARITY)) u_b (
        .Clk(Clk), .RstN(RstN),
        .tx_start(b_tx_start), .tx_data(b_tx_data),
        .txd(b_to_a), .tx_busy(b_tx_busy), .tx_done(b_tx_done),
        .rxd(a_to_b),
        .rx_reg(b_rx_reg), .rx_data(b_rx_data), .rx_valid(b_rx_valid),
        .parity_err(b_parity_err), .frame_err(b_frame_err),
        .rx_busy(), .os_tick()
    );
endmodule
