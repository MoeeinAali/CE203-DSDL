// Radix-4 Booth multiplier — DATAPATH.
//
// This module holds all the storage and arithmetic; it contains no
// sequencing decisions of its own. Every state change is requested by the
// control unit through the `load` / `step` strobes.
//
// Algorithm (modified / radix-4 Booth)
// ------------------------------------
// The accumulator register triple {A, Q, Q_1} is the classic Booth layout:
//
//     A (N+2 bits, signed)  Q (N bits)  Q_1 (1 bit)
//     \__ running partial product __/   \_ the bit shifted out last time
//
// Each iteration inspects the low three bits {Q[1], Q[0], Q_1} and adds one
// of five multiples of M to A, then shifts the whole triple RIGHT BY TWO
// arithmetically:
//
//     Q[1] Q[0] Q_1 | operation
//     --------------+-----------
//      0    0    0  |  A += 0
//      0    0    1  |  A += M
//      0    1    0  |  A += M
//      0    1    1  |  A += 2M
//      1    0    0  |  A -= 2M
//      1    0    1  |  A -= M
//      1    1    0  |  A -= M
//      1    1    1  |  A += 0
//
// Because two multiplier bits are retired per step, an N-bit operand needs
// only N/2 iterations instead of N — this is exactly the "shift more than
// one bit per clock" speed-up the lab asks for.
//
// Accumulator width: A is TWO bits wider than N. One extra bit is the usual
// Booth sign/guard bit, and a second is required because the -2M multiple
// must be representable: with M = -2^(N-1) (the most negative operand),
// 2M = -2^N and -2M = +2^N, which does NOT fit in N+1 signed bits. Sizing A
// and the addend to N+2 bits makes every one of the five multiples exact, so
// the most-negative multiplicand needs no special-casing.
module booth_datapath #(
    parameter integer N = 8              // operand width; must be even
) (
    input  wire                  Clk,
    input  wire                  RstN,       // async, active-low

    // --- control inputs -------------------------------------------------
    input  wire                  load,       // capture operands, clear acc
    input  wire                  step,       // perform one radix-4 iteration

    // --- operands -------------------------------------------------------
    input  wire signed [N-1:0]   Multiplicand,
    input  wire signed [N-1:0]   Multiplier,

    // --- status back to the control unit --------------------------------
    output wire [$clog2(N/2):0]  count,      // iterations still to run
    output wire                  count_zero, // 1 when no iteration is left

    // --- result ---------------------------------------------------------
    output wire signed [2*N-1:0] Product
);
    localparam integer ITER   = N / 2;              // radix-4 => N/2 steps
    localparam integer CNT_W  = $clog2(N/2) + 1;

    // ---- registers -----------------------------------------------------
    reg signed [N+1:0]   A;      // partial product, two guard bits (see above)
    reg        [N-1:0]   Q;      // multiplier, consumed 2 bits per step
    reg                  Q_1;    // the bit that fell off the bottom
    reg signed [N-1:0]   M;      // multiplicand, held constant
    reg        [CNT_W-1:0] cnt;  // remaining iterations

    assign count      = cnt;
    assign count_zero = (cnt == 0);

    // The product is the low 2N bits of {A, Q} after the last shift.
    assign Product = {A[N-1:0], Q};

    // ---- Booth recoding of the current 3-bit window --------------------
    wire [2:0] booth_window = {Q[1], Q[0], Q_1};

    // Sign-extended multiples of M, in the A register's width (N+2 bits).
    wire signed [N+1:0] M_ext  = {{2{M[N-1]}}, M};   // 1*M
    wire signed [N+1:0] M2_ext = {M[N-1], M, 1'b0};  // 2*M

    reg signed [N+1:0] addend;
    always @(*) begin
        case (booth_window)
            3'b000, 3'b111: addend =  {(N+2){1'b0}}; //  0
            3'b001, 3'b010: addend =  M_ext;         // +M
            3'b011:         addend =  M2_ext;        // +2M
            3'b100:         addend = -M2_ext;        // -2M
            3'b101, 3'b110: addend = -M_ext;         // -M
            default:        addend =  {(N+2){1'b0}};
        endcase
    end

    wire signed [N+1:0] A_sum = A + addend;

    // ---- arithmetic shift right by TWO of the triple {A, Q, Q_1} -------
    // The two bits leaving Q's bottom: Q[1] is discarded, Q[0] becomes the
    // new Q_1 for the next window.
    wire signed [N+1:0] A_next  = {A_sum[N+1], A_sum[N+1], A_sum[N+1:2]};
    wire       [N-1:0] Q_next  = {A_sum[1:0], Q[N-1:2]};
    wire               Q_1_next = Q[1];

    // ---- sequential update ---------------------------------------------
    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            A   <= {(N+2){1'b0}};
            Q   <= {N{1'b0}};
            Q_1 <= 1'b0;
            M   <= {N{1'b0}};
            cnt <= {CNT_W{1'b0}};
        end else if (load) begin
            A   <= {(N+2){1'b0}};
            Q   <= Multiplier;
            Q_1 <= 1'b0;
            M   <= Multiplicand;
            cnt <= ITER[CNT_W-1:0];
        end else if (step && cnt != 0) begin
            A   <= A_next;
            Q   <= Q_next;
            Q_1 <= Q_1_next;
            cnt <= cnt - 1'b1;
        end
    end
endmodule
