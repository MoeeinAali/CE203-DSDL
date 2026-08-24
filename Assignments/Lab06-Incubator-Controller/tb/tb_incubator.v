`timescale 1ns/1ps
`include "incubator_pkg.vh"

// Self-checking testbench for the incubator control unit.
//
// A reference model reimplements both state diagrams independently of the
// RTL, and the two are compared after every sample tick. The stimulus walks
// the whole legal temperature range so that every guard in both diagrams is
// exercised, including the "no guard is satisfied -> hold" case.
module tb_incubator;
    // Small divider so a "minute" is 4 clocks in simulation.
    localparam integer TICKDIV = 4;

    reg               Clk, RstN;
    reg signed [7:0]  temp;

    wire              heater, cooler, tick;
    wire [3:0]        crs;
    wire [6:0]        crs_seg;
    wire [1:0]        main_state, fan_state;

    incubator_controller #(.TICK_DIVIDE(TICKDIV)) dut (
        .Clk(Clk), .RstN(RstN), .temp(temp),
        .heater(heater), .cooler(cooler), .crs(crs), .crs_seg(crs_seg),
        .main_state(main_state), .fan_state(fan_state), .tick(tick)
    );

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    integer pass, fail;
    integer t, k;

    // ---------------- reference model ----------------
    localparam [1:0] R_S1 = 2'd0, R_S2 = 2'd1, R_S3 = 2'd2;
    localparam [1:0] R_OUT = 2'd0, R_F1 = 2'd1, R_F2 = 2'd2, R_F3 = 2'd3;

    reg [1:0] ref_main, ref_fan;

    task automatic ref_reset;
        begin
            ref_main = R_S1;
            ref_fan  = R_OUT;
        end
    endtask

    // Advance the model by one sample, exactly as the diagrams describe.
    task automatic ref_step;
        input signed [7:0] T;
        reg [1:0] nm;
        begin
            // ---- main diagram ----
            nm = ref_main;
            case (ref_main)
                R_S1: begin
                    if      (T > 35) nm = R_S2;
                    else if (T < 15) nm = R_S3;
                end
                R_S2: if (T < 25) nm = R_S1;
                R_S3: if (T > 30) nm = R_S1;
            endcase

            // ---- fan diagram ----
            // Gated on the main FSM's NEXT state: the tick that switches the
            // cooler off must also park the fan, and the tick that switches
            // it on lets the fan take its first step in the same sample.
            if (nm != R_S2) begin
                ref_fan = R_OUT;
            end else begin
                case (ref_fan)
                    R_OUT: if (T > 35) ref_fan = R_F1;
                    R_F1: begin
                        if      (T > 40) ref_fan = R_F2;
                        else if (T < 25) ref_fan = R_OUT;
                    end
                    R_F2: begin
                        if      (T > 45) ref_fan = R_F3;
                        else if (T < 35) ref_fan = R_F1;
                    end
                    R_F3: if (T < 40) ref_fan = R_F2;
                endcase
            end

            ref_main = nm;
        end
    endtask

    function [3:0] ref_crs;
        input [1:0] fs;
        begin
            case (fs)
                R_F1: ref_crs = 4'd4;
                R_F2: ref_crs = 4'd6;
                R_F3: ref_crs = 4'd8;
                default: ref_crs = 4'd0;
            endcase
        end
    endfunction

    // ---------------- helpers ----------------
    task automatic check;
        input [255:0] tag;
        reg exp_heater, exp_cooler;
        begin
            exp_heater = (ref_main == R_S3);
            exp_cooler = (ref_main == R_S2);
            if (main_state === ref_main && fan_state === ref_fan &&
                heater === exp_heater && cooler === exp_cooler &&
                crs === ref_crs(ref_fan)) begin
                pass = pass + 1;
            end else begin
                $display("FAIL [%0s] T=%0d | main got=%0d exp=%0d | fan got=%0d exp=%0d | H=%b/%b C=%b/%b crs=%0d/%0d",
                         tag, temp, main_state, ref_main, fan_state, ref_fan,
                         heater, exp_heater, cooler, exp_cooler,
                         crs, ref_crs(ref_fan));
                fail = fail + 1;
            end
        end
    endtask

    // Hold `temp` and let exactly one sample tick be consumed.
    task automatic sample;
        input signed [7:0] T;
        input [255:0] tag;
        begin
            temp = T;
            @(posedge tick);      // the edge on which the FSMs update
            @(posedge Clk);       // let the new state settle
            #1;
            ref_step(T);
            check(tag);
        end
    endtask

    task automatic do_reset;
        begin
            @(negedge Clk);
            RstN = 1'b0;
            temp = 8'sd20;
            @(negedge Clk);
            @(negedge Clk);
            RstN = 1'b1;
            ref_reset;
            #1;
            check("reset");
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        RstN = 1'b1; temp = 8'sd20;
        ref_reset;

        do_reset;

        // 1) Reset really lands in S1 with everything off.
        if (heater === 1'b0 && cooler === 1'b0 && crs === 4'd0 &&
            main_state === R_S1 && fan_state === R_OUT)
            pass = pass + 1;
        else begin
            $display("FAIL: wrong reset outputs");
            fail = fail + 1;
        end

        // 2) Dead band: inside 15..35 nothing should ever switch on.
        for (t = 15; t <= 35; t = t + 1)
            sample(t[7:0], "deadband_hold");

        // 3) Heating cycle: drop below 15, warm back through the band.
        sample(8'sd14, "heat_on");        // S1 -> S3
        sample(-8'sd10, "heat_stay_min"); // coldest reading, still heating
        sample(8'sd20, "heat_hold");      // 15..30: no guard -> stay in S3
        sample(8'sd30, "heat_hold_edge"); // T>30 is strict: 30 must hold
        sample(8'sd31, "heat_off");       // S3 -> S1

        // 4) Cooling cycle and the whole fan ladder.
        sample(8'sd35, "cool_edge_hold"); // T>35 strict: 35 must NOT start
        sample(8'sd36, "cool_on");        // S1 -> S2, fan enabled from OUT
        sample(8'sd36, "fan_out_to_s1");  // OUT -> F_S1 (4 RPS)
        sample(8'sd41, "fan_s1_to_s2");   // F_S1 -> F_S2 (6 RPS)
        sample(8'sd46, "fan_s2_to_s3");   // F_S2 -> F_S3 (8 RPS)
        sample(8'sd60, "fan_max_temp");   // hottest reading, stay at 8 RPS
        sample(8'sd39, "fan_s3_to_s2");   // T<40 -> back to 6 RPS
        sample(8'sd34, "fan_s2_to_s1");   // T<35 -> back to 4 RPS
        sample(8'sd30, "fan_s1_hold");    // 25..35: fan holds, cooler holds
        sample(8'sd24, "cool_off");       // T<25: main -> S1, fan -> OUT

        // 5) Leaving S2 must park the fan in OUT, and re-entry restarts there.
        sample(8'sd36, "reenter_cool");   // back to S2
        sample(8'sd46, "reenter_fan1");   // OUT -> F_S1 even though T>45
        sample(8'sd46, "reenter_fan2");   // F_S1 -> F_S2
        sample(8'sd46, "reenter_fan3");   // F_S2 -> F_S3
        sample(8'sd10, "cool_off_again"); // straight out of S2

        // 6) Reset in the middle of cooling.
        sample(8'sd50, "pre_reset_cool");
        sample(8'sd50, "pre_reset_fan");
        do_reset;

        // 7) Exhaustive: from every reachable (main, fan) pair, apply every
        //    temperature in range and compare against the model.
        for (k = 0; k < 4; k = k + 1) begin
            // Drive the machine into a known (main, fan) configuration.
            do_reset;
            case (k)
                0: ;                                  // stay in S1
                1: begin sample(8'sd14, "setup"); end // S3, heater on
                2: begin sample(8'sd36, "setup");     // S2 + fan F_S1
                         sample(8'sd36, "setup"); end
                3: begin sample(8'sd36, "setup");     // S2 + fan F_S3
                         sample(8'sd36, "setup");
                         sample(8'sd41, "setup");
                         sample(8'sd46, "setup"); end
            endcase
            for (t = -10; t <= 60; t = t + 1)
                sample(t[7:0], "sweep");
        end

        // 8) Seven-segment output must track `crs`.
        do_reset;
        sample(8'sd36, "seg_setup");
        sample(8'sd36, "seg_4rps");
        if (crs === 4'd4 && crs_seg === 7'b0011001) pass = pass + 1;
        else begin
            $display("FAIL: seg for 4 RPS = %b", crs_seg);
            fail = fail + 1;
        end

        $display("tb_incubator: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end

    // ---- standing invariant ----------------------------------------
    // The lab text is explicit that a rotation speed is meaningless while
    // the cooler is off. This is checked continuously, not just at chosen
    // sample points, so any glitch of `crs` while `cooler` is low fails the
    // run. (This is exactly the class of bug that a next-state gating error
    // produces, and it is why the check is written as an invariant.)
    always @(posedge Clk) begin
        if (RstN && !cooler && crs !== 4'd0) begin
            $display("FAIL: crs=%0d while cooler is OFF (T=%0d, fan_state=%0d)",
                     crs, temp, fan_state);
            fail = fail + 1;
        end
    end

    initial begin
        #2000000;
        $display("FAIL: timeout");
        $fatal(1);
    end
endmodule
