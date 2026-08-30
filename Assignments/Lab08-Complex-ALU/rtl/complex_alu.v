`include "complex_pkg.vh"

// Parts (a) and (b) of the lab: complex add/subtract and complex multiply.
//
// Why they are ONE module
// -----------------------
// The lab sheet says no adder or multiplier unit may be used more than once in
// the finished machine. Complex multiplication needs four real products and two
// real additions:
//
//     (ar + j*ai)(br + j*bi) = (ar*br - ai*bi) + j(ar*bi + ai*br)
//
// and complex addition needs two more real additions. If add/subtract and
// multiply were separate modules, the top level would contain two adders --
// exactly what the constraint forbids. So both operations live here, sharing
// one mul_unit and one add_unit, and the price of the constraint is paid in
// TIME instead of area: the module is sequential.
//
// Schedule
// --------
//   ADD / SUB     A_RE:  real parts                     2 cycles of work
//                 A_IM:  imaginary parts
//
//   MUL           M1: mul = ar*br                       4 cycles of work
//                 M2: mul = ai*bi , add = t1 - mul      (real part done)
//                 M3: mul = ar*bi
//                 M4: mul = ai*br , add = t3 + mul      (imag part done)
//
// Note how M2 and M4 use the adder on the product being computed in that very
// cycle while the multiplier is already busy with the next one. That overlap
// is what brings the multiply down from 6 cycles to 4 without adding a second
// unit of either kind.
module complex_alu (
    input  wire                    Clk,
    input  wire                    RstN,
    input  wire                    start,
    input  wire [1:0]              op,      // ALU_ADD / ALU_SUB / ALU_MUL
    input  wire [`CX_WORD-1:0]     a,       // { imag, real }
    input  wire [`CX_WORD-1:0]     b,
    output reg  [`CX_WORD-1:0]     y,
    output reg                     ovf,     // a component had to be clamped
    output wire                    busy,
    output reg                     done     // 1 clk pulse, y valid in that cycle
);
    localparam [2:0] IDLE = 3'd0,
                     A_RE = 3'd1, A_IM = 3'd2,
                     M1   = 3'd3, M2   = 3'd4, M3 = 3'd5, M4 = 3'd6;

    reg [2:0]                st;
    reg [`CX_WORD-1:0]       a_r, b_r;      // operands latched at start
    reg [1:0]                op_r;
    reg signed [15:0]        t1, t3;        // latched partial products
    reg                      sat_r;         // real part had to be clamped

    wire signed [7:0] ar = a_r[7:0],  ai = a_r[15:8];
    wire signed [7:0] br = b_r[7:0],  bi = b_r[15:8];

    // ---- the one multiplier and the one adder ----
    reg  signed [7:0]  mx, my;
    wire signed [15:0] mp;
    mul_unit u_mul (.x(mx), .y(my), .p(mp));

    reg  signed [16:0] ax, ay;
    reg                asub;
    wire signed [16:0] as;
    add_unit u_add (.x(ax), .y(ay), .sub(asub), .s(as));

    assign busy = (st != IDLE);

    // Clamp a 17-bit result into a signed 8-bit component.
    function signed [7:0] sat8;
        input signed [16:0] v;
        begin
            if      (v >  17'sd127) sat8 =  8'sd127;
            else if (v < -17'sd128) sat8 = -8'sd128;
            else                    sat8 =  v[7:0];
        end
    endfunction

    function clipped;
        input signed [16:0] v;
        begin
            clipped = (v > 17'sd127) || (v < -17'sd128);
        end
    endfunction

    // ---- operand routing: which numbers reach the two shared units ----
    always @(*) begin
        mx   = 8'sd0;
        my   = 8'sd0;
        ax   = 17'sd0;
        ay   = 17'sd0;
        asub = 1'b0;
        case (st)
            A_RE: begin
                ax   = {{9{ar[7]}}, ar};
                ay   = {{9{br[7]}}, br};
                asub = (op_r == `ALU_SUB);
            end
            A_IM: begin
                ax   = {{9{ai[7]}}, ai};
                ay   = {{9{bi[7]}}, bi};
                asub = (op_r == `ALU_SUB);
            end
            M1: begin mx = ar; my = br; end
            M2: begin
                mx   = ai;  my = bi;              // computing ai*bi ...
                ax   = {t1[15], t1};              // ... while the adder does
                ay   = {mp[15], mp};              //     ar*br - ai*bi
                asub = 1'b1;
            end
            M3: begin mx = ar; my = bi; end
            M4: begin
                mx   = ai;  my = br;              // computing ai*br ...
                ax   = {t3[15], t3};              // ... while the adder does
                ay   = {mp[15], mp};              //     ar*bi + ai*br
                asub = 1'b0;
            end
            default: ;
        endcase
    end

    always @(posedge Clk or negedge RstN) begin
        if (!RstN) begin
            st    <= IDLE;
            y     <= {`CX_WORD{1'b0}};
            ovf   <= 1'b0;
            done  <= 1'b0;
            a_r   <= {`CX_WORD{1'b0}};
            b_r   <= {`CX_WORD{1'b0}};
            op_r  <= 2'd0;
            t1    <= 16'sd0;
            t3    <= 16'sd0;
            sat_r <= 1'b0;
        end else begin
            done <= 1'b0;
            case (st)
                IDLE: if (start) begin
                    a_r   <= a;
                    b_r   <= b;
                    op_r  <= op;
                    sat_r <= 1'b0;
                    st    <= (op == `ALU_MUL) ? M1 : A_RE;
                end

                A_RE: begin
                    y[7:0] <= sat8(as);
                    sat_r  <= clipped(as);
                    st     <= A_IM;
                end
                A_IM: begin
                    y[15:8] <= sat8(as);
                    ovf     <= sat_r | clipped(as);
                    done    <= 1'b1;
                    st      <= IDLE;
                end

                M1: begin t1 <= mp; st <= M2; end
                M2: begin
                    y[7:0] <= sat8(as);
                    sat_r  <= clipped(as);
                    st     <= M3;
                end
                M3: begin t3 <= mp; st <= M4; end
                M4: begin
                    y[15:8] <= sat8(as);
                    ovf     <= sat_r | clipped(as);
                    done    <= 1'b1;
                    st      <= IDLE;
                end

                default: st <= IDLE;
            endcase
        end
    end
endmodule
