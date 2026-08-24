`include "incubator_pkg.vh"

// Incubator digital control unit — TOP LEVEL.
//
// The lab asks for the *digital control unit* only: the sensor, heater and
// cooler are outside the chip. The temperature therefore arrives as an
// 8-bit number and the actuators are represented by output signals which,
// on the FPGA board, drive LEDs and a seven-segment display instead of real
// hardware.
//
//        temp[7:0] ─┬─────────────────────────────► main_fsm ──► heater
//                   │                                  │         cooler
//                   │                                  │ (state==S2)
//                   │                                  ▼
//                   └─────────────────────────────► fan_fsm ───► crs[3:0]
//                                                  (enable)
//
//   tick_gen ──── tick (once per minute) ──► both FSMs
//
// Board-friendly outputs
// ----------------------
//   heater / cooler : drive two LEDs.
//   crs             : the fan speed in RPS as a plain number (0/4/6/8), ready
//                     for a seven-segment decoder.
//   crs_seg         : the same value already encoded for a common-anode
//                     seven-segment digit, so the design can be dropped onto
//                     the board without extra glue.
module incubator_controller #(
    // Clocks between temperature samples. Override in simulation.
    parameter integer TICK_DIVIDE = 60_000_000
) (
    input  wire               Clk,
    input  wire               RstN,          // async, active-low
    input  wire signed [7:0]  temp,          // from the sensor, -10..+60 C

    output wire               heater,        // LED / heater enable
    output wire               cooler,        // LED / cooler enable
    output wire [3:0]         crs,           // cooler speed in RPS (0/4/6/8)
    output wire [6:0]         crs_seg,       // seven-segment (common anode)
    output wire [1:0]         main_state,    // debug / waveform visibility
    output wire [1:0]         fan_state,
    output wire               tick
);
    wire        cooler_next;
    wire [1:0]  m_state;

    tick_gen #(.DIVIDE(TICK_DIVIDE)) u_tick (
        .Clk(Clk), .RstN(RstN), .tick(tick)
    );

    main_fsm u_main (
        .Clk         (Clk),
        .RstN        (RstN),
        .tick        (tick),
        .temp        (temp),
        .heater      (heater),
        .cooler      (cooler),
        .state       (m_state),
        .cooler_next (cooler_next)
    );

    // The fan machine runs only while the cooler is on. It is gated on the
    // main FSM's NEXT state so that the tick which switches the cooler off
    // also parks the fan in OUT -- otherwise the speed display would show a
    // turning fan for one whole sample period after the cooler stopped.

    fan_fsm u_fan (
        .Clk    (Clk),
        .RstN   (RstN),
        .tick   (tick),
        .temp   (temp),
        .enable (cooler_next),
        .crs    (crs),
        .state  (fan_state)
    );

    assign main_state = m_state;

    seven_seg_decoder u_seg (.value(crs), .seg(crs_seg));
endmodule
