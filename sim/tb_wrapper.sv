`timescale 1ns/1ps

// Define BALANCED macro for this test
`define BALANCED

module tb_warpper();

    // Testbench parameters
    parameter CLK_PERIOD = 10;
    parameter NMBR_CASCADES = 8;
    
    // DUT Signals
    reg CE;
    reg CLK;
    reg EN_VTC;
    reg IDATAIN;
    reg INC;
    reg RST;
    wire DATAOUT;
    
    // Testbench variables
    reg [31:0] test_count;
    integer i;
    
    // Instantiate the DUT
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
    ) dut (
        .CE(CE),
        .CLK(CLK),
        .EN_VTC(EN_VTC),
        .IDATAIN(IDATAIN),
        .INC(INC),
        .RST(RST),
        .DATAOUT(DATAOUT)
    );
    
    // Clock generation
    initial begin
        CLK = 0;
        forever #(CLK_PERIOD/2) CLK = ~CLK;
    end
        initial begin
        // Аннотация SDF задержек
        $sdf_annotate("../synth/out/cascade_delays.sdf", dut.cascade_delays_instance, , , "TYPICAL");
        $display("SDF файл загружен: ../synth/out/cascade_delays.sdf");
    end
    // Main test sequence for BALANCED mode
    initial begin
        // Initialize
        test_count = 0;
        CE = 0;
        EN_VTC = 0;
        IDATAIN = 0;
        INC = 0;
        RST = 0;
        
        #100;
        
        $display("[%0t] Starting BALANCED mode tests", $time);
        
        // Test 1: Verify reset sets select to 00000001
        test_count = 1;
        $display("[%0t] Test %0d: Reset to 00000001", $time, test_count);
        RST = 1;
        #(CLK_PERIOD * 2);
        RST = 0;
        #(CLK_PERIOD * 2);
        
        // Test 2: Increment in BALANCED mode
        test_count = 2;
        $display("[%0t] Test %0d: Increment sequence", $time, test_count);
        CE = 1;
        INC = 1;
        
        for (i = 0; i < 10; i = i + 1) begin
            IDATAIN = $random;
            #(CLK_PERIOD);
        end
        
        CE = 0;
        #(CLK_PERIOD * 2);
        
        // Test 3: Decrement in BALANCED mode
        test_count = 3;
        $display("[%0t] Test %0d: Decrement sequence", $time, test_count);
        RST = 1;
        #(CLK_PERIOD);
        RST = 0;
        #(CLK_PERIOD);
        
        CE = 1;
        INC = 0;
        
        for (i = 0; i < 10; i = i + 1) begin
            IDATAIN = $random;
            #(CLK_PERIOD);
        end
        
        CE = 0;
        #(CLK_PERIOD * 2);
        
        // Summary
        $display("\n[%0t] BALANCED mode tests completed", $time);
        $display("Total tests run: %0d", test_count);
        
        #100;
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("tb_warpper_delays_balanced.vcd");
        $dumpvars(0, tb_warpper);
    end

        // Загрузка SDF файла

    
endmodule