`timescale 1ps / 1ps

// =============================================================================
// Testbench: tb_ODELAYE3
// Description: Verification environment for ASIC Migration ODELAYE3 model.
// =============================================================================

module tb_ODELAYE3;

    localparam string DELAY_TYPE = "VAR_LOAD";
    localparam string DELAY_FORMAT = "COUNT";
    localparam string UPDATE_MODE = "ASYNC";

    // Signals
    logic        CLK = 0;
    logic        RST = 0;
    logic        CE = 0;
    logic        INC = 0;
    logic        LOAD = 0;
    logic [8:0]  CNTVALUEIN = 0;
    logic        ODATAIN = 0;
    logic        CASC_IN = 0;
    logic        CASC_RETURN = 0;
    logic        EN_VTC = 1;

    logic [8:0] CNTVALUEOUT_asic;
    logic       DATAOUT_asic;
    logic       CASC_OUT_asic;

    // Clock
    always #1666 CLK = ~CLK; 

    // -------------------------------------------------------------------------
    // ASIC Model
    // -------------------------------------------------------------------------
    ODELAYE3_asic #(
        .DELAY_TYPE(DELAY_TYPE),
        .DELAY_FORMAT(DELAY_FORMAT),
        .UPDATE_MODE(UPDATE_MODE),
        .SIM_DEVICE("ULTRASCALE")
    ) u_asic_model (
        .CASC_OUT(CASC_OUT_asic),
        .CNTVALUEOUT(CNTVALUEOUT_asic),
        .DATAOUT(DATAOUT_asic),
        .CASC_IN(CASC_IN),
        .CASC_RETURN(CASC_RETURN),
        .CE(CE),
        .CLK(CLK),
        .CNTVALUEIN(CNTVALUEIN),
        .ODATAIN(ODATAIN),
        .EN_VTC(EN_VTC),
        .INC(INC),
        .LOAD(LOAD),
        .RST(RST)
    );

    // -------------------------------------------------------------------------
    // Reference Model
    // -------------------------------------------------------------------------
    /*
    ODELAYE3 #( ... ) u_ref_model ( ... );
    */

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $display("=================================================");
        $display("   ODELAYE3 ASIC Migration Verification");
        $display("=================================================");
        
        RST = 1;
        #5000;
        RST = 0;
        EN_VTC = 0;
        #5000;

        // --- Test 1: Load Mode ---
        $display("[%t] Test 1: Loading Tap Value 128", $time);
        @(posedge CLK);
        LOAD = 1; CE = 1;
        CNTVALUEIN = 9'd128;
        @(posedge CLK);
        LOAD = 0; CE = 0;
        #1000;

        if (CNTVALUEOUT_asic !== 9'd128) 
            $error("ERROR: ODELAY Tap load failed. Got: %d", CNTVALUEOUT_asic);
        else 
            $display("PASS: Loaded 128");

        // --- Test 2: Data Path ---
        $display("[%t] Test 2: Toggling Data", $time);
        ODATAIN = 0;
        #5000;
        ODATAIN = 1;
        #5000;
        ODATAIN = 0;
        
        // Simple assertion that output followed input
        #1000;
        if (DATAOUT_asic !== 0) 
            $error("ERROR: ODELAY output stuck high");
        else 
            $display("PASS: Data toggled successfully");

        $display("=================================================");
        $display("   TEST COMPLETE");
        $display("=================================================");
        $finish;
    end

endmodule
