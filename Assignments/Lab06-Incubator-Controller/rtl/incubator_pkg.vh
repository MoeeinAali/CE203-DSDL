// Shared constants for the incubator controller.
//
// Temperature representation
// --------------------------
// The sensor delivers the container temperature as an 8-bit number covering
// -10 .. +60 degrees Celsius. An 8-bit SIGNED two's-complement code is used,
// so the value read from the sensor is the temperature in degrees directly:
//
//     8'shF6 = -10   (coldest)
//     8'sh00 =   0
//     8'sh3C = +60   (hottest)
//
// This keeps every comparison in the design a plain signed comparison
// against a decimal threshold, which is exactly how the state diagrams in
// the lab sheet are written (T<15, T>35, ...).
`ifndef INCUBATOR_PKG_VH
`define INCUBATOR_PKG_VH

// Sensor range limits
`define TEMP_MIN  (-8'sd10)
`define TEMP_MAX  ( 8'sd60)

// --- main FSM thresholds (left-hand state diagram) ---
`define TH_HEAT_ON    ( 8'sd15)   // S1 -> S3 when T < 15
`define TH_HEAT_OFF   ( 8'sd30)   // S3 -> S1 when T > 30
`define TH_COOL_OFF   ( 8'sd25)   // S2 -> S1 when T < 25
`define TH_COOL_ON    ( 8'sd35)   // S1 -> S2 when T > 35

// --- fan-speed FSM thresholds (right-hand state diagram) ---
`define TH_FAN_OUT    ( 8'sd25)   // F_S1 -> OUT  when T < 25
`define TH_FAN_IN     ( 8'sd35)   // OUT  -> F_S1 when T > 35
`define TH_FAN_DOWN1  ( 8'sd35)   // F_S2 -> F_S1 when T < 35
`define TH_FAN_UP1    ( 8'sd40)   // F_S1 -> F_S2 when T > 40
`define TH_FAN_DOWN2  ( 8'sd40)   // F_S3 -> F_S2 when T < 40
`define TH_FAN_UP2    ( 8'sd45)   // F_S2 -> F_S3 when T > 45

// --- cooler rotational speed encoding (RPS) ---
`define CRS_OFF  (4'd0)
`define CRS_4    (4'd4)
`define CRS_6    (4'd6)
`define CRS_8    (4'd8)

`endif
