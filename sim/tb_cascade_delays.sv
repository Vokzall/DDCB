`timescale 1ns/1ps

module tb_cascade_delays;

    logic       in;
    logic [9:0] select;
    logic       out;

    realtime t_start, t_end;
    real rise_delay, fall_delay, prev_rise;

    cascade_delays #(.Nmbr_cascades(5)) dut (
        .in(in),
        .select(select),
        .out(out)
    );

    initial begin
        $dumpfile("cascade_delays.vcd");
        $dumpvars(0, tb_cascade_delays);
    end

    initial begin
        in = 0;
        select = 10'd0;
        prev_rise = 0;
        #5;

        $display("");
        $display("==========================================================");
        $display("  CASCADE DELAYS - Behavioral Delay Measurement");
        $display("  Architecture: 5x (BUFV1->I0, direct->I1/I2) MUX3");
        $display("==========================================================");
        $display("  CNT | select[9:0]  | Rise(ps) | Fall(ps) | Delta_R(ps)");
        $display("------|--------------|----------|----------|------------");

        // CNT 0: all I2 (min delay) Rise=135, Fall=129
        select = 10'b01_01_01_01_01;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    0 | %10b | %8.0f | %8.0f |        ---", select, rise_delay, fall_delay);
        prev_rise = rise_delay;
        #5;

        // CNT 1: stg0=I1 Rise=148, Fall=143
        select = 10'b01_01_01_01_10;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    1 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 2: stg0=I0+buf Rise=168, Fall=164
        select = 10'b01_01_01_01_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    2 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 3: +stg1=I1 Rise=180, Fall=178
        select = 10'b01_01_01_10_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    3 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 4: +stg1=I0+buf Rise=200, Fall=198
        select = 10'b01_01_01_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    4 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 5: +stg2=I1 Rise=213, Fall=212
        select = 10'b01_01_10_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    5 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 6: +stg2=I0+buf Rise=233, Fall=233
        select = 10'b01_01_00_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    6 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 7: +stg3=I1 Rise=245, Fall=247
        select = 10'b01_10_00_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    7 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 8: +stg3=I0+buf Rise=265, Fall=268
        select = 10'b01_00_00_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    8 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 9: +stg4=I1 Rise=277, Fall=280
        select = 10'b10_00_00_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("    9 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        prev_rise = rise_delay;
        #5;

        // CNT 10: all I0+buf (max delay) Rise=296, Fall=300
        select = 10'b00_00_00_00_00;
        in = 0; #5;
        t_start = $realtime; in = 1; @(posedge out); t_end = $realtime;
        rise_delay = (t_end - t_start) * 1000.0;
        #5;
        t_start = $realtime; in = 0; @(negedge out); t_end = $realtime;
        fall_delay = (t_end - t_start) * 1000.0;
        $display("   10 | %10b | %8.0f | %8.0f | %+10.0f", select, rise_delay, fall_delay, rise_delay - prev_rise);
        #5;

        $display("==========================================================");
        $display("");
        $finish;
    end

endmodule
