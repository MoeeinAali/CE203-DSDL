`include "incubator_pkg.vh"

// Incubator main controller — LEFT-HAND state diagram.
//
//                    T<25
//         ┌──────────────────────────┐
//         ▼                          │
//   ┌──────────┐   T>35        ┌──────────┐
//   │    S2    │◄──────────────│    S1    │◄── reset
//   │ Heater:  │               │ Heater:  │
//   │   OFF    │               │   OFF    │
//   │ Cooler:  │               │ Cooler:  │
//   │   ON     │               │   OFF    │
//   └──────────┘               └──────────┘
//                                 ▲     │ T<15
//                            T>30 │     ▼
//                              ┌──────────┐
//                              │    S3    │
//                              │ Heater:ON│
//                              │ Cooler:  │
//                              │   OFF    │
//                              └──────────┘
//
// The diagram labels only the transitions listed above. For any temperature
// that does not satisfy the outgoing guard of the current state, the machine
// HOLDS its state — that is what gives the controller its hysteresis (the
// 15..35 dead band around S1) and stops the heater and cooler chattering on
// and off around a single set point.
//
// `tick` is the once-per-minute sample strobe: the lab specifies that the
// temperature is read from the sensor once every minute, so the FSM advances
// only on a tick, not on every clock.
module main_fsm (
    input  wire               Clk,
    input  wire               RstN,        // async, active-low
    input  wire               tick,        // 1-clock strobe, once per minute
    input  wire signed [7:0]  temp,        // degrees C, -10 .. +60

    output wire               heater,      // 1 = heater energised
    output wire               cooler,      // 1 = cooler energised
    output wire [1:0]         state,       // current state (debug/waveforms)
    output wire               cooler_next  // 1 if THIS tick moves us into S2
);
    localparam [1:0] S1 = 2'd0,   // both off  (reset state)
                     S2 = 2'd1,   // cooler on
                     S3 = 2'd2;   // heater on

    reg [1:0] cur, nxt;

    assign state  = cur;
    // Moore outputs: they depend on the state alone.
    assign heater = (cur == S3);
    assign cooler = (cur == S2);

    // The state this FSM will hold *after* the current tick. The fan machine
    // is gated on this rather than on `cooler`, so that on the very tick that
    // leaves S2 the fan parks in OUT instead of taking one more step with a
    // cooler that is already switching off.
    assign cooler_next = (nxt == S2);

    always @(*) begin
        nxt = cur;                       // default: hold (see note above)
        case (cur)
            S1: begin
                // Only one of these can be true: 15 < 35, so the guards are
                // mutually exclusive and the priority here is cosmetic.
                if (temp > `TH_COOL_ON)       nxt = S2;   // T > 35 -> cool
                else if (temp < `TH_HEAT_ON)  nxt = S3;   // T < 15 -> heat
            end
            S2: if (temp < `TH_COOL_OFF)      nxt = S1;   // T < 25 -> off
            S3: if (temp > `TH_HEAT_OFF)      nxt = S1;   // T > 30 -> off
            default:                          nxt = S1;
        endcase
    end

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)     cur <= S1;
        else if (tick) cur <= nxt;
    end
endmodule
