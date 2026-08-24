// Radix-4 Booth multiplier — CONTROL UNIT.
//
// A three-state Moore FSM. It owns no data: it only decides *when* the
// datapath loads operands and *when* it performs an iteration, and it
// watches the datapath's `count_zero` status flag to know when to stop.
//
//   IDLE  --start--> BUSY  --count_zero--> DONE --start--> BUSY
//                     ^                      |
//                     |______ (else) ________|
//
// `busy` is high while a multiplication is in flight, `done` is a level
// that stays high until the next `start`, so a slow consumer cannot miss
// the result.
module booth_control #(
    parameter integer N = 8
) (
    input  wire Clk,
    input  wire RstN,          // async, active-low

    input  wire start,         // request a new multiplication
    input  wire count_zero,    // status from the datapath

    output reg  load,          // strobe: capture operands
    output reg  step,          // strobe: run one radix-4 iteration
    output wire busy,
    output wire done
);
    localparam [1:0] S_IDLE = 2'd0,
                     S_BUSY = 2'd1,
                     S_DONE = 2'd2;

    reg [1:0] state, next_state;

    // ---- state register --------------------------------------------------
    always @(posedge Clk or negedge RstN) begin
        if (!RstN) state <= S_IDLE;
        else       state <= next_state;
    end

    // ---- next-state logic ------------------------------------------------
    always @(*) begin
        case (state)
            S_IDLE: next_state = start      ? S_BUSY : S_IDLE;
            // Leave BUSY only once the datapath reports no iteration left.
            S_BUSY: next_state = count_zero ? S_DONE : S_BUSY;
            S_DONE: next_state = start      ? S_BUSY : S_DONE;
            default: next_state = S_IDLE;
        endcase
    end

    // ---- output logic ----------------------------------------------------
    // `load` fires on the transition into BUSY, so operands are captured on
    // the same edge the FSM enters BUSY; `step` runs throughout BUSY.
    always @(*) begin
        load = 1'b0;
        step = 1'b0;
        case (state)
            S_IDLE: load = start;
            S_BUSY: step = 1'b1;
            S_DONE: load = start;
            default: ;
        endcase
    end

    assign busy = (state == S_BUSY);
    assign done = (state == S_DONE);
endmodule
