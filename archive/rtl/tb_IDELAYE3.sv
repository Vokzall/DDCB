`timescale 1ps / 1ps

// =============================================================================
// Testbench: tb_IDELAYE3
// Description: Verification environment for ASIC Migration IDELAYE3 model.
//              Designed to compare "Behavioral ASIC Model" vs "Reference FPGA".
// =============================================================================

module tb_IDELAYE3;

    // -------------------------------------------------------------------------
    // Test Parameters
    // -------------------------------------------------------------------------
    localparam string DELAY_TYPE = "VAR_LOAD";
    localparam string DELAY_FORMAT = "COUNT";
    localparam string UPDATE_MODE = "ASYNC";
    localparam real REF_CLK_FREQ = 300.0;
    
    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    // Shared Inputs
    logic        CLK = 0;
    logic        RST = 0;
    logic        CE = 0;
    logic        INC = 0;
    logic        LOAD = 0;
    logic [8:0]  CNTVALUEIN = 0;
    logic        IDATAIN = 0;
    logic        DATAIN = 0;
    logic        CASC_IN = 0;
    logic        CASC_RETURN = 0;
    logic        EN_VTC = 1;

    // Outputs - ASIC Model
    logic [8:0] CNTVALUEOUT_asic;
    logic       DATAOUT_asic;
    logic       CASC_OUT_asic;

    // Outputs - Reference Model (FPGA Primitive)
    logic [8:0] CNTVALUEOUT_ref;
    logic       DATAOUT_ref;
    logic       CASC_OUT_ref;

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    always #1666 CLK = ~CLK; // ~300 MHz

    // -------------------------------------------------------------------------
    // 1. DUT: ASIC Migration Model
    // -------------------------------------------------------------------------
    IDELAYE3_asic #(
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
        .DATAIN(DATAIN),
        .EN_VTC(EN_VTC),
        .IDATAIN(IDATAIN),
        .INC(INC),
        .LOAD(LOAD),
        .RST(RST)
    );

    // -------------------------------------------------------------------------
    // 2. Reference: FPGA Primitive (UNISIM)
    // -------------------------------------------------------------------------
    // NOTE: Uncomment the following block when running in Vivado or Xcelium 
    //       where 'glbl' and 'unisim' libraries are compiled.
    /*
    IDELAYE3 #(
        .DELAY_TYPE(DELAY_TYPE),
        .DELAY_FORMAT(DELAY_FORMAT),
        .UPDATE_MODE(UPDATE_MODE),
        .SIM_DEVICE("ULTRASCALE")
    ) u_ref_model (
        .CASC_OUT(CASC_OUT_ref),
        .CNTVALUEOUT(CNTVALUEOUT_ref),
        .DATAOUT(DATAOUT_ref),
        .CASC_IN(CASC_IN),
        .CASC_RETURN(CASC_RETURN),
        .CE(CE),
        .CLK(CLK),
        .CNTVALUEIN(CNTVALUEIN),
        .DATAIN(DATAIN),
        .EN_VTC(EN_VTC),
        .IDATAIN(IDATAIN),
        .INC(INC),
        .LOAD(LOAD),
        .RST(RST)
    );
    */

    // -------------------------------------------------------------------------
    // 3. Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $display("=================================================");
        $display("   IDELAYE3 ASIC Migration Verification");
        $display("=================================================");
        
        // --- Initialization ---
        RST = 1;
        #10000;
        RST = 0;
        EN_VTC = 0; // Disable VT compensation to allow variable updates
        #5000;

        // --- Test 1: Load Mode ---
        $display("[%t] Test 1: Loading Tap Value 50", $time);
        @(posedge CLK);
        LOAD = 1; 
        CE = 1;
        CNTVALUEIN = 9'd50;
        @(posedge CLK);
        LOAD = 0; 
        CE = 0;
        #2000;
        
        // Self-Check
        if (CNTVALUEOUT_asic !== 9'd50) 
            $error("ERROR: ASIC Model failed to load value 50. Got: %d", CNTVALUEOUT_asic);
        else 
            $display("PASS: ASIC Model loaded 50");

        // --- Test 2: Increment ---
        $display("[%t] Test 2: Incrementing 10 steps", $time);
        repeat(10) begin
            @(posedge CLK);
            INC = 1; CE = 1;
            @(posedge CLK);
            CE = 0;
            #100;
        end
        #1000;
        
        if (CNTVALUEOUT_asic !== 9'd60) 
            $error("ERROR: ASIC Model failed increment. Expected 60, Got: %d", CNTVALUEOUT_asic);
        else 
            $display("PASS: ASIC Model incremented to 60");

        // --- Test 3: Decrement ---
        $display("[%t] Test 3: Decrementing 5 steps", $time);
        repeat(5) begin
            @(posedge CLK);
            INC = 0; CE = 1;
            @(posedge CLK);
            CE = 0;
            #100;
        end
        #1000;
        
        if (CNTVALUEOUT_asic !== 9'd55) 
            $error("ERROR: ASIC Model failed decrement. Expected 55, Got: %d", CNTVALUEOUT_asic);
        else 
            $display("PASS: ASIC Model decremented to 55");

        // --- Test 4: Data Delay Propagation ---
        $display("[%t] Test 4: Checking Data Path", $time);
        IDATAIN = 0;
        #5000;
        IDATAIN = 1;
        // In the behavioral model, delay is approx (TapCount * 5ps)
        // 55 taps * 5ps = 275ps.
        #500;
        if (DATAOUT_asic !== 1) 
            $error("ERROR: Data did not propagate through IDELAYE3");
        else 
            $display("PASS: Data propagated successfully");

        // --- Comparison Check (If Ref Model exists) ---
        /*
        if (CNTVALUEOUT_asic !== CNTVALUEOUT_ref)
            $error("MISMATCH: ASIC Tap (%d) != FPGA Tap (%d)", CNTVALUEOUT_asic, CNTVALUEOUT_ref);
        */

        #5000;
        $display("=================================================");
        $display("   TEST COMPLETE");
        $display("=================================================");
        $finish;
    end

endmodule
