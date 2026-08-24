`include "incubator_pkg.vh"

module incubator_controller #(
    parameter integer TICK_DIVIDE = 60_000_000
) (
    input  wire               Clk,
    input  wire               RstN,        
    input  wire signed [7:0]  temp,        

    output wire               heater,      
    output wire               cooler,      
    output wire [3:0]         crs,         
    output wire [6:0]         crs_seg,     
    output wire [1:0]         main_state,  
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
