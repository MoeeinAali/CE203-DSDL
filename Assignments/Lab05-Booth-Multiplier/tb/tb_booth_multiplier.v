`timescale 1ns/1ps

module tb_booth_multiplier;
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

    integer pass, fail;
    integer ai, bi;
    integer cycles, max_cycles, min_cycles;
    reg signed [2*N-1:0] expected;
    reg signed [N-1:0]   sa, sb;

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    task automatic multiply;
        input signed [N-1:0] a;
        input signed [N-1:0] b;
        begin
            @(negedge Clk);
            Multiplicand = a;
            Multiplier   = b;
            start        = 1'b1;
            @(negedge Clk);
            start = 1'b0;

            cycles = 0;
            while (!done) begin
                @(posedge Clk); #1;
                cycles = cycles + 1;
                if (cycles > 100) begin
                    $display("FAIL: timeout waiting for done (a=%0d b=%0d)", a, b);
                    $fatal(1);
                end
            end
            #1;
        end
    endtask

    task automatic check;
        input signed [N-1:0] a;
        input signed [N-1:0] b;
        begin
            multiply(a, b);
            expected = a * b;
            if (Product === expected) begin
                pass = pass + 1;
            end else begin
                $display("FAIL a=%0d b=%0d  got=%0d (%h)  exp=%0d (%h)",
                         a, b, Product, Product, expected, expected);
                fail = fail + 1;
            end
            if (cycles > max_cycles) max_cycles = cycles;
            if (cycles < min_cycles) min_cycles = cycles;
        end
    endtask

    task automatic do_reset;
        begin
            @(negedge Clk);
            start = 1'b0; Multiplicand = 0; Multiplier = 0;
            RstN = 1'b0;
            @(negedge Clk);
            RstN = 1'b1;
            #1;
            if (busy !== 1'b0 || done !== 1'b0) begin
                $display("FAIL: flags not clear after reset (busy=%b done=%b)",
                         busy, done);
                fail = fail + 1;
            end else pass = pass + 1;
        end
    endtask

    initial begin
        pass = 0; fail = 0;
        max_cycles = 0; min_cycles = 1000;
        RstN = 1'b1; start = 0; Multiplicand = 0; Multiplier = 0;

        do_reset;

        check(  0,   0);
        check(  0,  57);
        check( 57,   0);
        check(  1,   1);
        check(  1,  -1);
        check( -1,   1);
        check( -1,  -1);
        check(127, 127);  
        check(127,-128);
        check(-128,127);
        check(-128,-128); 
        check(-128,   1);
        check(  1,-128);
        check(-128,  -1);
        check( -1,-128);
        check( 85, -86);  
        check(-86,  85);
        check( 85,  85);
        check(-86, -86);

        check( 12,  10);
        check(-12,  10);
        check( 12, -10);
        check(-12, -10);

        @(negedge Clk);
        Multiplicand = 100; Multiplier = 100; start = 1'b1;
        @(negedge Clk); start = 1'b0;
        @(posedge Clk);      
        @(posedge Clk);
        do_reset;
        check(6, 7);        

        for (ai = -128; ai <= 127; ai = ai + 1)
            for (bi = -128; bi <= 127; bi = bi + 1) begin
                sa = ai[N-1:0];
                sb = bi[N-1:0];
                check(sa, sb);
            end

        $display("cycles per multiply: min=%0d max=%0d (N=%0d, radix-4 => %0d iterations)",
                 min_cycles, max_cycles, N, N/2);
        $display("tb_booth_multiplier: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
