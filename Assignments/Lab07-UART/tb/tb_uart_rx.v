`timescale 1ns/1ps
`include "uart_pkg.vh"

module tb_uart_rx;
    localparam integer OSD = 3;
    localparam integer OS  = `UART_OVERSAMPLE;

    reg  Clk = 1'b0, RstN = 1'b1, line = 1'b1;
    wire os_tick;

    wire [`UART_RX_REG_BITS-1:0] reg_e, reg_o;
    wire [`UART_DATA_BITS-1:0]   dat_e, dat_o;
    wire vld_e, per_e, fer_e, bsy_e;
    wire vld_o, per_o, fer_o, bsy_o;

    baud_gen #(.DIVISOR(OSD)) u_baud (.Clk(Clk), .RstN(RstN), .tick(os_tick));

    uart_rx #(.ODD_PARITY(1'b0)) dut_even (
        .Clk(Clk), .RstN(RstN), .os_tick(os_tick), .rxd(line),
        .rx_reg(reg_e), .rx_data(dat_e), .rx_valid(vld_e),
        .parity_err(per_e), .frame_err(fer_e), .rx_busy(bsy_e)
    );

    uart_rx #(.ODD_PARITY(1'b1)) dut_odd (
        .Clk(Clk), .RstN(RstN), .os_tick(os_tick), .rxd(line),
        .rx_reg(reg_o), .rx_data(dat_o), .rx_valid(vld_o),
        .parity_err(per_o), .frame_err(fer_o), .rx_busy(bsy_o)
    );

    always #5 Clk = ~Clk;

    integer ntick = 0;
    always @(posedge Clk) if (os_tick) ntick = ntick + 1;

    integer pass = 0, fail = 0;
    integer c, i;

    reg                          seen_e, seen_o;
    reg [`UART_RX_REG_BITS-1:0]  cap_e,  cap_o;
    reg                          cpe_e,  cfe_e, cpe_o, cfe_o;

    always @(posedge Clk) begin
        if (vld_e) begin seen_e <= 1'b1; cap_e <= reg_e; cpe_e <= per_e; cfe_e <= fer_e; end
        if (vld_o) begin seen_o <= 1'b1; cap_o <= reg_o; cpe_o <= per_o; cfe_o <= fer_o; end
    end

    task automatic chk;
        input [255:0] name;
        input         ok;
        begin
            if (ok) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FAIL @%0t: %0s", $time, name);
            end
        end
    endtask

    task automatic hold_ticks;             
        input integer n;
        integer target;
        begin
            target = ntick + n;
            while (ntick < target) @(posedge Clk);
            @(negedge Clk);
        end
    endtask

    task automatic drive_bit;
        input b;
        begin
            line = b;
            hold_ticks(OS);
        end
    endtask

    task automatic clear_flags;
        begin
            seen_e = 1'b0; seen_o = 1'b0;
            cpe_e  = 1'b0; cfe_e  = 1'b0;
            cpe_o  = 1'b0; cfe_o  = 1'b0;
        end
    endtask

    task automatic drive_frame;
        input [`UART_DATA_BITS-1:0] d;
        input                       par;
        input                       stop;
        integer k;
        begin
            drive_bit(1'b0);
            drive_bit(par);
            for (k = `UART_DATA_BITS-1; k >= 0; k = k - 1) drive_bit(d[k]);
            drive_bit(stop);
        end
    endtask

    initial begin
        clear_flags;
        @(negedge Clk); RstN = 1'b0;
        repeat (4) @(negedge Clk); RstN = 1'b1;
        hold_ticks(2);

        chk("idle after reset", bsy_e === 1'b0 && bsy_o === 1'b0);

        for (c = 0; c < 128; c = c + 1) begin
            clear_flags;
            drive_frame(c[6:0], ^c[6:0], 1'b1);       
            hold_ticks(2);
            chk("even: frame accepted",  seen_e);
            chk("even: register value",  cap_e === {^c[6:0], c[6:0]});
            chk("even: no parity error", cpe_e === 1'b0);
            chk("even: no frame error",  cfe_e === 1'b0);
            chk("even: data output",     dat_e === c[6:0]);
            chk("odd DUT flags parity",  seen_o && cpe_o === 1'b1);

            clear_flags;
            drive_frame(c[6:0], ~(^c[6:0]), 1'b1);   
            hold_ticks(2);
            chk("odd: frame accepted",   seen_o);
            chk("odd: register value",   cap_o === {~(^c[6:0]), c[6:0]});
            chk("odd: no parity error",  cpe_o === 1'b0);
            chk("even DUT flags parity", seen_e && cpe_e === 1'b1);
        end

        clear_flags;
        drive_frame(7'h41, ~(^7'h41), 1'b1);
        hold_ticks(2);
        chk("bad parity reported",       seen_e && cpe_e === 1'b1);
        chk("data still captured",       cap_e[`UART_DATA_BITS-1:0] === 7'h41);

        clear_flags;
        drive_frame(7'h55, ^7'h55, 1'b0);
        hold_ticks(2);
        chk("framing error reported",    seen_e && cfe_e === 1'b1);
        line = 1'b1; hold_ticks(4);            
        clear_flags;
        drive_frame(7'h2A, ^7'h2A, 1'b1);
        hold_ticks(2);
        chk("recovers after frame error", seen_e && cap_e === {^7'h2A, 7'h2A});
        chk("flags cleared on good frame", cfe_e === 1'b0 && cpe_e === 1'b0);

        clear_flags;
        line = 1'b0; hold_ticks(OS/4);
        line = 1'b1; hold_ticks(2*OS);
        chk("glitch rejected", !seen_e && !seen_o && bsy_e === 1'b0);

        clear_flags;
        drive_frame(7'h7F, ^7'h7F, 1'b1);
        chk("first of a burst",  seen_e && cap_e === {^7'h7F, 7'h7F});
        clear_flags;
        drive_frame(7'h00, ^7'h00, 1'b1);
        chk("second of a burst", seen_e && cap_e === {^7'h00, 7'h00});
        clear_flags;
        drive_frame(7'h3C, ^7'h3C, 1'b1);
        hold_ticks(2);
        chk("third of a burst",  seen_e && cap_e === {^7'h3C, 7'h3C});

        $display("tb_uart_rx: Passed: %0d, Failed: %0d", pass, fail);
        if (fail != 0) $fatal(1);
        $finish;
    end
endmodule
