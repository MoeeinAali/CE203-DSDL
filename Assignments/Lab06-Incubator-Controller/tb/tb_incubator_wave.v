`timescale 1ns/1ps

// Presentation-friendly demo that dumps a VCD covering a full thermal cycle:
// cold (heater on) -> dead band -> hot (cooler on, fan climbing 4->6->8 RPS)
// -> cooling back down the ladder -> cooler off (fan parks at 0).
`ifndef VCD_FILE
`define VCD_FILE "waves/incubator.vcd"
`endif

module tb_incubator_wave;
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

    task automatic sample;
        input signed [7:0] T;
        begin
            temp = T;
            @(posedge tick);
            @(posedge Clk);
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_incubator_wave);

        RstN = 1'b1; temp = 8'sd20;
        @(negedge Clk); RstN = 1'b0;
        @(negedge Clk); @(negedge Clk); RstN = 1'b1;

        sample(8'sd20);   // dead band: everything off
        sample(8'sd12);   // T<15  -> heater ON  (S3)
        sample(8'sd20);   // 15..30: heater stays on (hysteresis)
        sample(8'sd33);   // T>30  -> heater OFF (S1)
        sample(8'sd38);   // T>35  -> cooler ON  (S2), fan starts at 4 RPS
        sample(8'sd42);   // T>40  -> 6 RPS
        sample(8'sd47);   // T>45  -> 8 RPS
        sample(8'sd38);   // T<40  -> 6 RPS
        sample(8'sd33);   // T<35  -> 4 RPS
        sample(8'sd22);   // T<25  -> cooler OFF, fan parks at 0 RPS
        sample(8'sd22);   // stays off

        #40;
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
