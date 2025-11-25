`timescale 1ps / 1ps

module IDELAYE3_asic #(
    parameter string CASCADE = "NONE",          // "NONE", "MASTER", "SLAVE_END", "SLAVE_MIDDLE"
    parameter string DELAY_FORMAT = "TIME",     // "TIME", "COUNT"
    parameter string DELAY_SRC = "IDATAIN",     // "IDATAIN", "DATAIN"
    parameter string DELAY_TYPE = "FIXED",      // "FIXED", "VARIABLE", "VAR_LOAD"
    parameter int DELAY_VALUE = 0,              // 0 to 1250 ps
    parameter bit IS_CLK_INVERTED = 0,
    parameter bit IS_RST_INVERTED = 0,
    parameter real REFCLK_FREQUENCY = 300.0,
    parameter string SIM_DEVICE = "ULTRASCALE",
    parameter string UPDATE_MODE = "ASYNC"      // "ASYNC", "MANUAL", "SYNC"
) (
    output logic CASC_OUT,
    output logic [8:0] CNTVALUEOUT,
    output logic DATAOUT,

    input logic CASC_IN,
    input logic CASC_RETURN,
    input logic CE,
    input logic CLK,
    input logic [8:0] CNTVALUEIN,
    input logic DATAIN,
    input logic EN_VTC,
    input logic IDATAIN,
    input logic INC,
    input logic LOAD,
    input logic RST
);

    // -------------------------------------------------------------------------
    // 1. Parameter Validation & Normalization
    // -------------------------------------------------------------------------
    // Normalize control signals based on inversion attributes
    logic clk_in, rst_in;
    assign clk_in = IS_CLK_INVERTED ? ~CLK : CLK;
    assign rst_in = IS_RST_INVERTED ? ~RST : RST;

    // -------------------------------------------------------------------------
    // 2. Tap Controller Logic (Synthesizable)
    // -------------------------------------------------------------------------
    // The delay line is controlled by a 9-bit counter (0-511 taps)
    logic [8:0] tap_count;
    logic [8:0] next_tap_count;
    
    // Internal shadow register for ASYNC/SYNC update modes
    logic [8:0] tap_count_shadow;

    always_ff @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            // Reset behavior depends on DELAY_FORMAT
            if (DELAY_FORMAT == "COUNT")
                tap_count <= DELAY_VALUE[8:0];
            else 
                tap_count <= 0; // Simplified for behavioral model (assume 0 for TIME mode reset)
        end else begin
            if (CE) begin
                if (LOAD) begin
                    // Load Mode
                    if (DELAY_TYPE == "VAR_LOAD") 
                        tap_count <= CNTVALUEIN;
                    else if (DELAY_TYPE == "VARIABLE")
                        tap_count <= tap_count; // LOAD ignored in VARIABLE
                end else if (INC) begin
                    // Increment
                    if (tap_count < 511) tap_count <= tap_count + 1;
                    else tap_count <= 0; // Wrap around
                end else begin
                    // Decrement (INC=0, CE=1, LOAD=0)
                    if (tap_count > 0) tap_count <= tap_count - 1;
                    else tap_count <= 511; // Wrap around
                end
            end
        end
    end

    // Output the current tap value
    assign CNTVALUEOUT = tap_count;

    // -------------------------------------------------------------------------
    // 3. Data Path Muxing (Cascading Logic)
    // -------------------------------------------------------------------------
    logic data_mux_out;
    logic casc_out_internal;

    always_comb begin
        // Default assignments
        data_mux_out = 1'b0;
        casc_out_internal = 1'b0;

        case (CASCADE)
            "NONE": begin
                data_mux_out = (DELAY_SRC == "DATAIN") ? DATAIN : IDATAIN;
                casc_out_internal = 1'b0;
            end
            "MASTER": begin
                // In MASTER mode, we send data out to CASC_OUT and receive returned data
                casc_out_internal = (DELAY_SRC == "DATAIN") ? DATAIN : IDATAIN;
                data_mux_out = CASC_RETURN;
            end
            "SLAVE_END": begin
                data_mux_out = CASC_IN;
                casc_out_internal = 1'b0;
            end
            "SLAVE_MIDDLE": begin
                data_mux_out = CASC_RETURN;
                casc_out_internal = CASC_IN;
            end
            default: begin
                data_mux_out = (DELAY_SRC == "DATAIN") ? DATAIN : IDATAIN;
            end
        endcase
    end

    assign CASC_OUT = casc_out_internal;

    // -------------------------------------------------------------------------
    // 4. Behavioral Delay Application
    // -------------------------------------------------------------------------
    // Note: For ASIC synthesis, this block should be replaced by:
    // a) A hard macro instance (DCDL)
    // b) A chain of buffers with a mux controlled by 'tap_count'
    // c) A Liberty timing model
    
    real current_delay_ps;
    
    // Approximate delay calculation (Behavioral Only)
    // Assuming ~5ps per tap for UltraScale+ approximation
    always_comb begin
        current_delay_ps = (tap_count * 5.0) + DELAY_VALUE; 
    end

    // Apply Transport Delay
    // This syntax is for SIMULATION ONLY (Xcelium).
    // It will be ignored or flagged by Genus during synthesis.
    assign #(current_delay_ps * 1ps) DATAOUT = data_mux_out;

endmodule
