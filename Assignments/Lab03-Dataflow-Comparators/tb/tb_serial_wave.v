`timescale 1ns/1ps

// Short, presentation-friendly serial-comparator demo that dumps a VCD.
// Compile with -DDUT_MODULE=serial_comparator_ff|serial_comparator_assign
//             -DVCD_FILE=\"waves/serial_ff.vcd\" (etc.)
`ifndef DUT_MODULE
`define DUT_MODULE serial_comparator_ff
`endif
`ifndef VCD_FILE
`define VCD_FILE "waves/serial.vcd"
`endif

module tb_serial_wave;
    reg clk, reset, A, B;
    wire GT, EQ, LT;

    `DUT_MODULE dut (
        .clk(clk), .reset(reset), .A(A), .B(B),
        .GT(GT), .EQ(EQ), .LT(LT)
    );

    // Same timing contract as tb_serial_comparator.
    task automatic cycle;
        input bit_a;
        input bit_b;
        begin
            A = bit_a;
            B = bit_b;
            #2;
            clk = 1;
            #5;
            clk = 0;
            #3;
        end
    endtask

    task automatic do_reset;
        begin
            clk = 0;
            A = 0;
            B = 0;
            reset = 1;
            #4;
            reset = 0;
            #2;
        end
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_serial_wave);
        clk = 0;
        reset = 0;
        A = 0;
        B = 0;

        // Scenario: compare A=0100 vs B=0011 (MSB first).
        // Expected: EQ, EQ, GT (sticky), GT, GT
        do_reset;
        cycle(1'b0, 1'b0); // bit3: equal
        cycle(1'b1, 1'b0); // bit2: A>B → GT latches
        cycle(1'b0, 1'b1); // bit1: sticky GT
        cycle(1'b0, 1'b1); // bit0: sticky GT

        // Mid-stream reset, then A=0001 vs B=0010 → LT sticky
        do_reset;
        cycle(1'b0, 1'b0);
        cycle(1'b0, 1'b0);
        cycle(1'b0, 1'b1); // LT
        cycle(1'b1, 1'b0); // sticky LT

        #5;
        $display("Wrote VCD: %s", `VCD_FILE);
        $finish;
    end
endmodule
