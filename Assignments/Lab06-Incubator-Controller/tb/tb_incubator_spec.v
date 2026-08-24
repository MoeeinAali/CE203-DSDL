`timescale 1ns/1ps
// Diagram-conformance testbench.
//
// tb_incubator.v checks the design against a reference model. That is a
// strong check, but a model written by the same hand can repeat the same
// misreading of the spec -- which is exactly what happened here: both RTL
// and model initially let the fan take one extra step on the tick that
// switched the cooler off.
//
// This testbench is therefore written directly from the two state diagrams
// in the lab sheet, as a list of behaviours that must hold, with no shared
// model. It is the check that caught that bug.
module tb_incubator_spec;
  localparam integer TD = 4;
  reg Clk=0, RstN=1; reg signed [7:0] temp=8'sd20;
  wire heater,cooler,tick; wire [3:0] crs; wire [6:0] seg;
  wire [1:0] ms, fs;
  incubator_controller #(.TICK_DIVIDE(TD)) dut(.Clk(Clk),.RstN(RstN),.temp(temp),
    .heater(heater),.cooler(cooler),.crs(crs),.crs_seg(seg),
    .main_state(ms),.fan_state(fs),.tick(tick));
  always #5 Clk=~Clk;
  integer bad=0, checks=0;
  task automatic step(input signed [7:0] T);
  begin temp=T; @(posedge tick); @(posedge Clk); #1; end endtask
  task automatic want(input [255:0] w, input ok);
  begin checks=checks+1; if(!ok) begin $display("  MISMATCH: %0s (T=%0d ms=%0d fs=%0d H=%b C=%b crs=%0d)",w,temp,ms,fs,heater,cooler,crs); bad=bad+1; end end endtask
  task automatic rst; begin @(negedge Clk); RstN=0; @(negedge Clk); @(negedge Clk); RstN=1; #1; end endtask
  initial begin
    rst;
    $display("A) reset => S1, all off");
    want("reset S1 off", ms==0 && !heater && !cooler && crs==0);

    $display("B) strict inequalities on the boundaries");
    rst; step(8'sd35); want("T=35 must NOT turn cooler on", !cooler);
    rst; step(8'sd36); want("T=36 turns cooler on", cooler);
    rst; step(8'sd15); want("T=15 must NOT turn heater on", !heater);
    rst; step(8'sd14); want("T=14 turns heater on", heater);
    rst; step(8'sd14); step(8'sd30); want("T=30 keeps heater on", heater);
    rst; step(8'sd14); step(8'sd31); want("T=31 turns heater off", !heater);
    rst; step(8'sd36); step(8'sd25); want("T=25 keeps cooler on", cooler);
    rst; step(8'sd36); step(8'sd24); want("T=24 turns cooler off", !cooler);

    $display("C) fan ladder speeds are 4/6/8 RPS");
    rst; step(8'sd36); step(8'sd36); want("fan 4RPS", crs==4);
    step(8'sd41); want("fan 6RPS", crs==6);
    step(8'sd46); want("fan 8RPS", crs==8);
    step(8'sd39); want("back to 6RPS", crs==6);
    step(8'sd34); want("back to 4RPS", crs==4);

    $display("D) fan is meaningless while cooler is off => crs must be 0");
    rst; want("crs=0 in S1", crs==0);
    rst; step(8'sd14); want("crs=0 while heating (S3)", crs==0 && heater);
    // even at a very hot reading, if main is not in S2 the fan must be OUT
    rst; step(8'sd60); step(8'sd60); step(8'sd60);
    want("hot => cooler on, fan running", cooler && crs>0);
    step(8'sd10);  // drops out of S2
    want("leaving S2 parks fan at 0", !cooler && crs==0 && fs==0);

    $display("E) re-entering S2 restarts the fan from OUT (not from 8RPS)");
    // On the entry tick the main FSM moves S1->S2 and the fan's own
    // OUT->S1 guard (T>35) is satisfied by the same reading, so the cooler
    // starts at its lowest speed on that tick. The point being checked is
    // that it restarts from the BOTTOM of the ladder, not from the 8 RPS it
    // held before it was parked.
    step(8'sd60);
    want("re-entry: fan restarts at 4RPS (not 8)", cooler && crs==4);
    step(8'sd60);
    want("re-entry: then climbs to 6RPS", crs==6);

    $display("F) hold behaviour inside the dead band");
    rst; step(8'sd20); want("T=20 from reset stays S1", ms==0 && !heater && !cooler);
    rst; step(8'sd14); step(8'sd20); want("T=20 while heating keeps heating", heater);
    rst; step(8'sd36); step(8'sd30); want("T=30 while cooling keeps cooling", cooler);

    $display("tb_incubator_spec: Passed: %0d, Failed: %0d", checks - bad, bad);
    if (bad != 0) $fatal(1);
    $finish;
  end
endmodule
