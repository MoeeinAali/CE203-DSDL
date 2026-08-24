`timescale 1ns/1ps

// Presentation-friendly demo that dumps a VCD showing the datapath's
// internal Booth iteration: the {A, Q, Q_1} triple shifting right by TWO
// each clock, the recoded addend, and the control FSM's load/step strobes.
`ifndef VCD_FILE
`define VCD_FILE "waves/booth.vcd"
`endif

module tb_booth_wave;
    localparam integer N = 8;

    reg                   Clk, RstN, start;
    reg  signed [N-1:0]   Multiplicand, Multiplier;
    wire signed [2*N-1:0] Product;
    wire                  busy, done;

    booth_multiplier #(.N(N)) dut (
        .Clk(Clk), .RstN(RstN), .start(start),
        .Multiplicand(Multiplicand), .Multiplier(Multiplier),
        .Product(Product), .busy(busy), .done(done)
    );

    // Mirror a few internal datapath signals so they appear in the VCD
    // with short, readable names.
    wire [2:0]  window = dut.u_datapath.booth_window;
    wire        load   = dut.load;
    wire        step   = dut.step;
    wire [3:0]  cnt    = dut.u_datapath.cnt;

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    task automatic multiply;
        input signed [N-1:0] a;
        input signed [N-1:0] b;
        begin
            @(negedge Clk);
            Multiplicand = a; Multiplier = b; start = 1'b1;
            @(negedge Clk); start = 1'b0;
            while (!done) @(posedge Clk);
            @(negedge Clk);
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_booth_wave);

        RstN = 1'b1; start = 0; Multiplicand = 0; Multiplier = 0;
        @(negedge Clk); RstN = 1'b0;
        @(negedge Clk); RstN = 1'b1;

        // Two multiplications back to back: one mixed-sign, one all-negative,
        // so both the +M and -M recodings are exercised on screen.
        multiply(8'sd25, -8'sd7);    // = -175
        multiply(-8'sd12, -8'sd11);  // = +132

        #20;
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
