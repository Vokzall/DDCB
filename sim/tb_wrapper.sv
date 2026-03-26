`timescale 1ns/1ps

`define Nmbr_cascades 11

module tb_wrapper();

    parameter CLK_PERIOD = 10;
    parameter NUM_STEPS  = 32;   // 0..31
    parameter INC_PER_STEP = 16; // CNTVALUEOUT[8:4] -> 16 increments per LUT step

    // Common signals
    reg        CE, CLK, EN_VTC, INC, RST;

    // IDELAYE3 signals
    reg        idatain;
    wire       idelay_out;

    // ODELAYE3 signals
    reg        odatain;
    wire       odelay_out;
    wire [8:0] odelay_cntval;

    // Timing measurement
    realtime   t_rise_start, t_fall_start;
    realtime   idelay_rise, idelay_fall;
    realtime   odelay_rise, odelay_fall;

    integer step;
    integer inc_i;

    // =========================================================
    // DUT: IDELAYE3
    // =========================================================
    IDELAYE3 #(
        .CASCADE("NONE"),
        .DELAY_FORMAT("TIME"),
        .DELAY_SRC("IDATAIN"),
        .DELAY_TYPE("VARIABLE"),
        .DELAY_VALUE(0),
        .IS_CLK_INVERTED(0),
        .IS_RST_INVERTED(0),
        .REFCLK_FREQUENCY(200.0),
        .SIM_DEVICE("ULTRASCALE"),
        .UPDATE_MODE("ASYNC")
    ) u_idelay (
        .CE      (CE),
        .CLK     (CLK),
        .EN_VTC  (EN_VTC),
        .IDATAIN (idatain),
        .INC     (INC),
        .RST     (RST),
        .DATAOUT (idelay_out)
    );

    // =========================================================
    // DUT: ODELAYE3
    // =========================================================
    ODELAYE3 #(
        .CASCADE("NONE"),
        .DELAY_FORMAT("TIME"),
        .DELAY_TYPE("VARIABLE"),
        .DELAY_VALUE(0),
        .IS_CLK_INVERTED(0),
        .IS_RST_INVERTED(0),
        .REFCLK_FREQUENCY(200.0),
        .SIM_DEVICE("ULTRASCALE"),
        .UPDATE_MODE("ASYNC")
    ) u_odelay (
        .CE          (CE),
        .CLK         (CLK),
        .EN_VTC      (EN_VTC),
        .ODATAIN     (odatain),
        .INC         (INC),
        .RST         (RST),
        .DATAOUT     (odelay_out),
        .CNTVALUEOUT (odelay_cntval)
    );

    // =========================================================
    // Clock
    // =========================================================
    initial begin
        CLK = 0;
        forever #(CLK_PERIOD/2) CLK = ~CLK;
    end

    // =========================================================
    // SDF annotation
    // =========================================================
    initial begin
        $sdf_annotate("../synth/out/cascade_delays.sdf", u_idelay.cascade_delays_instance, , , "TYPICAL");
        $sdf_annotate("../synth/out/cascade_delays.sdf", u_odelay.cascade_delays_netlist,   , , "TYPICAL");
        $display("[%0t] SDF annotated", $time);
    end

    // =========================================================
    // Main test
    // =========================================================
    initial begin
        // Init
        CE      = 0;
        EN_VTC  = 0;
        INC     = 1;
        RST     = 0;
        idatain = 0;
        odatain = 0;

        // Reset
        #20;
        RST = 1;
        #(CLK_PERIOD * 4);
        RST = 0;
        #(CLK_PERIOD * 6); // wait for reset synchronizer to release clk_gated

        $display("=======================================================================");
        $display(" Step | CNTVAL |   IDELAY Rise |  IDELAY Fall |  ODELAY Rise | ODELAY Fall");
        $display("=======================================================================");

        for (step = 0; step < NUM_STEPS; step = step + 1) begin

            // --- Measure at current step ---

            // Rising edge pulse: idatain/odatain 0->1
            #(CLK_PERIOD * 2);
            t_rise_start = $realtime;
            idatain = 1;
            odatain = 1;

            @(posedge idelay_out);
            idelay_rise = $realtime - t_rise_start;

            // Need to also catch odelay rise - it may have already triggered
            // Use fork-join for simultaneous measurement next time
            // For now, measure separately with new pulse

            // Reset inputs
            #(CLK_PERIOD * 2);

            // Falling edge pulse: 1->0
            t_fall_start = $realtime;
            idatain = 0;
            odatain = 0;

            @(negedge idelay_out);
            idelay_fall = $realtime - t_fall_start;

            #(CLK_PERIOD * 2);

            // Measure ODELAY with separate pulse
            t_rise_start = $realtime;
            odatain = 1;
            idatain = 1;

            @(posedge odelay_out);
            odelay_rise = $realtime - t_rise_start;

            #(CLK_PERIOD * 2);

            t_fall_start = $realtime;
            odatain = 0;
            idatain = 0;

            @(negedge odelay_out);
            odelay_fall = $realtime - t_fall_start;

            #(CLK_PERIOD * 2);

            $display("  %3d |  %4d  | %10.1f ps | %10.1f ps | %10.1f ps | %10.1f ps",
                     step, odelay_cntval,
                     idelay_rise * 1000.0, idelay_fall * 1000.0,
                     odelay_rise * 1000.0, odelay_fall * 1000.0);

            // --- Increment to next step (16 counter ticks per LUT step) ---
            if (step < NUM_STEPS - 1) begin
                CE  = 1;
                INC = 1;
                for (inc_i = 0; inc_i < INC_PER_STEP; inc_i = inc_i + 1) begin
                    @(posedge CLK);
                end
                CE = 0;
                #(CLK_PERIOD * 2);
            end
        end

        $display("=======================================================================");
        $display("[%0t] All %0d steps tested. Simulation complete.", $time, NUM_STEPS);
        #100;
        $finish;
    end

    // =========================================================
    // Waveform dump
    // =========================================================
    initial begin
        $dumpfile("tb_wrapper.vcd");
        $dumpvars(0, tb_wrapper);
    end

endmodule
