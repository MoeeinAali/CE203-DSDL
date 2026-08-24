// Radix-4 Booth multiplier — TOP LEVEL.
//
// The lab asks for the datapath and the control unit to be designed
// separately and then joined; this module is exactly that join and contains
// no logic of its own beyond the wiring.
//
//                 start ──►┌──────────────┐
//                          │   CONTROL    │
//                 done  ◄──│    (FSM)     │
//                 busy  ◄──└──┬────┬──────┘
//                    load ────┘    │ step
//                             ▼    ▼
//                          ┌──────────────┐
//   Multiplicand, Multiplier ─►│  DATAPATH  │──► Product
//                          └──────┬───────┘
//                                 └── count_zero ──► (back to control)
//
// Timing: after `start`, the result is valid when `done` rises, which takes
// N/2 + 1 clocks (N/2 radix-4 iterations plus the IDLE→BUSY transition).
module booth_multiplier #(
    parameter integer N = 8              // operand width; must be even
) (
    input  wire                  Clk,
    input  wire                  RstN,       // async, active-low
    input  wire                  start,
    input  wire signed [N-1:0]   Multiplicand,
    input  wire signed [N-1:0]   Multiplier,
    output wire signed [2*N-1:0] Product,
    output wire                  busy,
    output wire                  done
);
    // control <-> datapath handshake
    wire load, step, count_zero;

    booth_control #(.N(N)) u_control (
        .Clk        (Clk),
        .RstN       (RstN),
        .start      (start),
        .count_zero (count_zero),
        .load       (load),
        .step       (step),
        .busy       (busy),
        .done       (done)
    );

    booth_datapath #(.N(N)) u_datapath (
        .Clk          (Clk),
        .RstN         (RstN),
        .load         (load),
        .step         (step),
        .Multiplicand (Multiplicand),
        .Multiplier   (Multiplier),
        .count        (),               // exposed for debug/waveforms only
        .count_zero   (count_zero),
        .Product      (Product)
    );
endmodule
