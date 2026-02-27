`timescale 1ns/1ps

module tb_odelay_idelay;

    // Clock
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // ODELAYE3 signals
    logic        odelay_ce;
    logic        odelay_en_vtc;
    logic        odelay_inc;
    logic        odelay_rst;
    logic        odelay_datain;
    wire         odelay_dataout;
    logic [8:0]  odelay_cntval;

    // IDELAYE3 signals
    logic        idelay_ce;
    logic        idelay_en_vtc;
    logic        idelay_inc;
    logic        idelay_rst;
    logic        idelay_datain;
    wire         idelay_dataout;

    // Measurement
    realtime t_start, t_end;
    real rise_delay, fall_delay;
    integer pass_num;
    integer step;

    // DUT: ODELAYE3
    ODELAYE3 #(.DELAY_VALUE(500)) u_odelay (
        .CE(odelay_ce),
        .CLK(clk),
        .EN_VTC(odelay_en_vtc),
        .ODATAIN(odelay_datain),
        .INC(odelay_inc),
        .RST(odelay_rst),
        .DATAOUT(odelay_dataout),
        .CNTVALUEOUT(odelay_cntval)
    );

    // DUT: IDELAYE3
    IDELAYE3 u_idelay (
        .CE(idelay_ce),
        .CLK(clk),
        .EN_VTC(idelay_en_vtc),
        .IDATAIN(idelay_datain),
        .INC(idelay_inc),
        .RST(idelay_rst),
        .DATAOUT(idelay_dataout)
    );

    // Waveform dump
    initial begin
        $dumpfile("odelay_idelay.vcd");
        $dumpvars(0, tb_odelay_idelay);
    end

    // Main test
    initial begin
        // Init
        odelay_ce     = 0;
        odelay_en_vtc = 0;
        odelay_inc    = 1;
        odelay_rst    = 0;
        odelay_datain = 0;

        idelay_ce     = 0;
        idelay_en_vtc = 0;
        idelay_inc    = 1;
        idelay_rst    = 0;
        idelay_datain = 0;

        // Reset both
        #10;
        odelay_rst = 1;
        idelay_rst = 1;
        @(posedge clk);
        #1;
        odelay_rst = 0;
        idelay_rst = 0;
        #20;

        // ============================================================
        //  ODELAYE3: 2 full passes (0 -> 10 -> wrap -> 0 -> 10)
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  ODELAYE3 - 2 full passes, CNT 0..10 (delay increases)");
        $display("============================================================");

        odelay_inc = 1;

        pass_num = 0;
        while (pass_num < 2) begin
            $display("");
            $display("--- Pass %0d ---", pass_num + 1);
            $display("  Step | CNT | CNTVAL | Rise(ps) | Fall(ps)");
            $display("-------|-----|--------|----------|--------");

            step = 0;
            while (step < 11) begin
                // Settle
                #20;

                // Measure rise
                odelay_datain = 0;
                #5;
                t_start = $realtime;
                odelay_datain = 1;
                @(posedge odelay_dataout);
                t_end = $realtime;
                rise_delay = (t_end - t_start) * 1000.0;

                // Measure fall
                #5;
                t_start = $realtime;
                odelay_datain = 0;
                @(negedge odelay_dataout);
                t_end = $realtime;
                fall_delay = (t_end - t_start) * 1000.0;

                $display("  %4d | %3d |  %4d  | %8.0f | %8.0f",
                    step, u_odelay.cnt, odelay_cntval, rise_delay, fall_delay);

                // Increment counter (CE=1, INC=1, on posedge CLK)
                odelay_ce = 1;
                @(posedge clk);
                #1;
                odelay_ce = 0;

                step = step + 1;
            end

            pass_num = pass_num + 1;
        end

        #20;

        // ============================================================
        //  IDELAYE3: 2 full passes (0 -> 11 -> wrap -> 0 -> 11)
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  IDELAYE3 - 2 full passes, CNT 0..11 (delay increases)");
        $display("============================================================");

        // Reset IDELAYE3
        idelay_rst = 1;
        @(posedge clk);
        #1;
        idelay_rst = 0;
        #20;

        idelay_inc = 1;

        pass_num = 0;
        while (pass_num < 2) begin
            $display("");
            $display("--- Pass %0d ---", pass_num + 1);
            $display("  Step | CNT | Rise(ps) | Fall(ps)");
            $display("-------|-----|----------|--------");

            step = 0;
            while (step < 12) begin
                // Settle
                #20;

                // Measure rise
                idelay_datain = 0;
                #5;
                t_start = $realtime;
                idelay_datain = 1;
                @(posedge idelay_dataout);
                t_end = $realtime;
                rise_delay = (t_end - t_start) * 1000.0;

                // Measure fall
                #5;
                t_start = $realtime;
                idelay_datain = 0;
                @(negedge idelay_dataout);
                t_end = $realtime;
                fall_delay = (t_end - t_start) * 1000.0;

                $display("  %4d | %3d | %8.0f | %8.0f",
                    step, u_idelay.cnt, rise_delay, fall_delay);

                // Increment counter
                idelay_ce = 1;
                @(posedge clk);
                #1;
                idelay_ce = 0;

                step = step + 1;
            end

            pass_num = pass_num + 1;
        end

        #20;
        $display("");
        $display("============================================================");
        $display("  Done.");
        $display("============================================================");
        $display("");
        $finish;
    end

endmodule
