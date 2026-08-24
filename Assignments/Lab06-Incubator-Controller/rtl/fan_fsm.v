`include "incubator_pkg.vh"

// Cooler fan-speed controller — RIGHT-HAND state diagram.
//
//                        T<40
//              ┌───────────────────────┐
//              ▼                       │
//        ┌──────────┐            ┌──────────┐
//        │    S3    │   T>45     │    S2    │
//        │ CRS=8RPS │◄───────────│ CRS=6RPS │
//        └──────────┘            └──────────┘
//                                  ▲      │ T<35
//                             T>40 │      ▼
//        ┌──────────┐            ┌──────────┐
//        │   OUT    │   T>35     │    S1    │
//        │ (idle)   │───────────►│ CRS=4RPS │
//        └──────────┘◄───────────└──────────┘
//                        T<25
//
// Enable rule (from the lab text)
// ------------------------------
// This machine is active ONLY while the main FSM sits in its S2 state, i.e.
// while the cooler is actually running — setting a rotation speed for a
// cooler that is switched off is meaningless. The lab sheet states that when
// the main FSM is not in S2 this machine "enters its OUT state", so `enable`
// going low forces OUT rather than freezing the current state. A later
// re-entry into S2 therefore always restarts from OUT.
//
// As in the main FSM, a temperature that satisfies no outgoing guard leaves
// the state unchanged.
module fan_fsm (
    input  wire               Clk,
    input  wire               RstN,      // async, active-low
    input  wire               tick,      // once-per-minute sample strobe
    input  wire signed [7:0]  temp,
    input  wire               enable,    // 1 only while main FSM is in S2

    output wire [3:0]         crs,       // cooler rotational speed, in RPS
    output wire [1:0]         state      // exposed for debug/waveforms
);
    localparam [1:0] OUT  = 2'd0,   // fan idle (cooler is off)
                     F_S1 = 2'd1,   // 4 RPS
                     F_S2 = 2'd2,   // 6 RPS
                     F_S3 = 2'd3;   // 8 RPS

    reg [1:0] cur, nxt;

    assign state = cur;

    // Moore output: the speed is a property of the state alone.
    // OUT reports 0 RPS because the fan is not turning at all then.
    assign crs = (cur == F_S1) ? `CRS_4 :
                 (cur == F_S2) ? `CRS_6 :
                 (cur == F_S3) ? `CRS_8 : `CRS_OFF;

    always @(*) begin
        nxt = cur;                        // default: hold
        case (cur)
            OUT:  if (temp > `TH_FAN_IN)    nxt = F_S1;  // T > 35
            F_S1: begin
                if      (temp > `TH_FAN_UP1) nxt = F_S2; // T > 40
                else if (temp < `TH_FAN_OUT) nxt = OUT;  // T < 25
            end
            F_S2: begin
                if      (temp > `TH_FAN_UP2)   nxt = F_S3; // T > 45
                else if (temp < `TH_FAN_DOWN1) nxt = F_S1; // T < 35
            end
            F_S3: if (temp < `TH_FAN_DOWN2)  nxt = F_S2;  // T < 40
            default:                         nxt = OUT;
        endcase
    end

    always @(posedge Clk or negedge RstN) begin
        if (!RstN)       cur <= OUT;
        else if (!enable) cur <= OUT;     // cooler off => park in OUT
        else if (tick)    cur <= nxt;
    end
endmodule
