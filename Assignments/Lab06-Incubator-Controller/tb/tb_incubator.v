`timescale 1ns/1ps
`include "incubator_pkg.vh"

module tb_incubator;
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

    localparam [1:0] R_S1 = 2'd0, R_S2 = 2'd1, R_S3 = 2'd2;
    localparam [1:0] R_OUT = 2'd0, R_F1 = 2'd1, R_F2 = 2'd2, R_F3 = 2'd3;

    reg [1:0] ref_main, ref_fan;

    task automatic ref_reset;
        begin
            ref_main = R_S1;
            ref_fan  = R_OUT;
        end
    endtask

    task automatic ref_step;
        input signed [7:0] T;
        reg [1:0] nm;
        begin
            nm = ref_main;
            case (ref_main)
                R_S1: begin
                    if      (T > 35) nm = R_S2;
                    else if (T < 15) nm = R_S3;
                end
                R_S2: if (T < 25) nm = R_S1;
                R_S3: if (T > 30) nm = R_S1;
            endcase

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

    task automatic sample;
        input signed [7:0] T;
        input [255:0] tag;
        begin
            temp = T;
            @(posedge tick);
            @(posedge Clk);
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

        if (heater === 1'b0 && cooler === 1'b0 && crs === 4'd0 &&
            main_state === R_S1 && fan_state === R_OUT)
            pass = pass + 1;
        else begin
            $display("FAIL: wrong reset outputs");
            fail = fail + 1;
        end

        for (t = 15; t <= 35; t = t + 1)
            sample(t[7:0], "deadband_hold");

        sample(8'sd14, "heat_on");       
        sample(-8'sd10, "heat_stay_min"); 
        sample(8'sd20, "heat_hold");
        sample(8'sd30, "heat_hold_edge"); 
        sample(8'sd31, "heat_off");      

        sample(8'sd35, "cool_edge_hold"); 
        sample(8'sd36, "cool_on");       
        sample(8'sd36, "fan_out_to_s1"); 
        sample(8'sd41, "fan_s1_to_s2");  
        sample(8'sd46, "fan_s2_to_s3"); 
        sample(8'sd60, "fan_max_temp"); 
        sample(8'sd39, "fan_s3_to_s2");  
        sample(8'sd34, "fan_s2_to_s1");  
        sample(8'sd30, "fan_s1_hold");   
        sample(8'sd24, "cool_off");    

        sample(8'sd36, "reenter_cool");
        sample(8'sd46, "reenter_fan1");  
        sample(8'sd46, "reenter_fan2");  
        sample(8'sd46, "reenter_fan3");  
        sample(8'sd10, "cool_off_again");

        sample(8'sd50, "pre_reset_cool");
        sample(8'sd50, "pre_reset_fan");
        do_reset;

        for (k = 0; k < 4; k = k + 1) begin
            do_reset;
            case (k)
                0: ;                                  
                1: begin sample(8'sd14, "setup"); end 
                2: begin sample(8'sd36, "setup");    
                         sample(8'sd36, "setup"); end
                3: begin sample(8'sd36, "setup");    
                         sample(8'sd36, "setup");
                         sample(8'sd41, "setup");
                         sample(8'sd46, "setup"); end
            endcase
            for (t = -10; t <= 60; t = t + 1)
                sample(t[7:0], "sweep");
        end

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
