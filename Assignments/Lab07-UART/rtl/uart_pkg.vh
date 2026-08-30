// Shared parameters for the UART transmitter / receiver pair.
//
// Frame layout (exactly as specified in the lab sheet)
// ---------------------------------------------------
// The line idles HIGH. One character is 10 bit-times long:
//
//        +-------+--------+----+----+----+----+----+----+----+-------+
//   idle | START | PARITY | D6 | D5 | D4 | D3 | D2 | D1 | D0 | STOP  | idle
//        +-------+--------+----+----+----+----+----+----+----+-------+
//          1 bit   1 bit   <--------- 7 data bits ---------->  1 bit
//
// Two points differ from a "textbook" 8N1 UART and both come straight from
// the lab sheet:
//
//   1. The parity bit is sent BEFORE the data, not after it. A transmitter
//      therefore has to know the whole character before it starts shifting,
//      which is why the data is loaded in parallel and the parity is computed
//      combinationally at load time.
//
//   2. The payload is 7 bits (ASCII), and the receiver stores the 8 bits that
//      follow the start bit -- parity plus data -- into one 8-bit register.
//      Sending the data MSB first makes that register come out as
//      {parity, D6..D0}, i.e. the ASCII code sits in the low 7 bits with no
//      bit reversal anywhere in the design.
`ifndef UART_PKG_VH
`define UART_PKG_VH

`define UART_DATA_BITS   7      // ASCII payload
`define UART_FRAME_BITS  10     // start + parity + 7 data + stop
`define UART_RX_REG_BITS 8      // {parity, D6..D0}

// Number of oversampling ticks per bit time. 16x is the usual choice: it is
// coarse enough to be cheap and fine enough that the mid-bit sample point
// stays inside the bit even with a few percent of baud-rate mismatch.
`define UART_OVERSAMPLE  16

`endif
