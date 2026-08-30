`include "uart_pkg.vh"

module uart #(
    parameter integer OS_DIVISOR = 16,
    parameter         ODD_PARITY = 1'b0
) (
    input  wire                          Clk,
    input  wire                          RstN,

    input  wire                          tx_start,
    input  wire [`UART_DATA_BITS-1:0]    tx_data,
    output wire                          txd,
    output wire                          tx_busy,
    output wire                          tx_done,

    input  wire                          rxd,
    output wire [`UART_RX_REG_BITS-1:0]  rx_reg,     
    output wire [`UART_DATA_BITS-1:0]    rx_data,
    output wire                          rx_valid,
    output wire                          parity_err,
    output wire                          frame_err,
    output wire                          rx_busy,

    output wire                          os_tick 
);
    baud_gen #(.DIVISOR(OS_DIVISOR)) u_baud (
        .Clk(Clk), .RstN(RstN), .tick(os_tick)
    );

    uart_tx #(.ODD_PARITY(ODD_PARITY)) u_tx (
        .Clk      (Clk),
        .RstN     (RstN),
        .os_tick  (os_tick),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .txd      (txd),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    uart_rx #(.ODD_PARITY(ODD_PARITY)) u_rx (
        .Clk        (Clk),
        .RstN       (RstN),
        .os_tick    (os_tick),
        .rxd        (rxd),
        .rx_reg     (rx_reg),
        .rx_data    (rx_data),
        .rx_valid   (rx_valid),
        .parity_err (parity_err),
        .frame_err  (frame_err),
        .rx_busy    (rx_busy)
    );
endmodule
