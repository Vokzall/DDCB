`timescale 1ps / 1ps

module ODELAYE3_asic #(
    parameter string CASCADE = "NONE",          // "NONE", "MASTER", "SLAVE_END", "SLAVE_MIDDLE"
    parameter string DELAY_FORMAT = "TIME",
    parameter string DELAY_TYPE = "FIXED",
    parameter int DELAY_VALUE = 0,
    parameter bit IS_CLK_INVERTED = 0,
    parameter bit IS_RST_INVERTED = 0,
    parameter real REFCLK_FREQUENCY = 300.0,
    parameter string SIM_DEVICE = "ULTRASCALE",
    parameter string UPDATE_MODE = "ASYNC"
) (
    output logic CASC_OUT,
    output logic [8:0] CNTVALUEOUT,
    output logic DATAOUT,

    input logic CASC_IN,
    input logic CASC_RETURN,
    input logic CE,
    input logic CLK,
    input logic [8:0] CNTVALUEIN,
    input logic EN_VTC,
    input logic INC,
    input logic LOAD,
    input logic ODATAIN, // Note: Different input name vs IDELAY
    input logic RST
);

    // -------------------------------------------------------------------------
    // 1. Parameter Validation & Normalization
    // -------------------------------------------------------------------------
    logic clk_in, rst_in;
    assign clk_in = IS_CLK_INVERTED ? ~CLK : CLK;
    assign rst_in = IS_RST_INVERTED ? ~RST : RST;

    // -------------------------------------------------------------------------
    // 2. Tap Controller Logic
    // -------------------------------------------------------------------------
    logic [8:0] tap_count;

    always_ff @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            if (DELAY_FORMAT == "COUNT")
                tap_count <= DELAY_VALUE[8:0];
            else 
                tap_count <= 0;
        end else begin
            if (CE) begin
                if (LOAD) begin
                    // ODELAY supports VAR_LOAD similar to IDELAY
                    if (DELAY_TYPE == "VAR_LOAD") 
                        tap_count <= CNTVALUEIN;
                    // In VARIABLE mode, ODELAY ignores LOAD
                end else if (INC) begin
                    if (tap_count < 511) tap_count <= tap_count + 1;
                    else tap_count <= 0;
                end else begin
                    if (tap_count > 0) tap_count <= tap_count - 1;
                    else tap_count <= 511;
                end
            end
        end
    end

    assign CNTVALUEOUT = tap_count;

    // -------------------------------------------------------------------------
    // 3. Data Path Muxing
    // -------------------------------------------------------------------------
    logic data_mux_out;
    logic casc_out_internal;

    always_comb begin
        data_mux_out = 1'b0;
        casc_out_internal = 1'b0;

        case (CASCADE)
            "NONE": begin
                data_mux_out = ODATAIN;
                casc_out_internal = 1'b0;
            end
            "MASTER": begin
                casc_out_internal = ODATAIN; // Output to cascade chain
                data_mux_out = CASC_RETURN;  // Input from return
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
                data_mux_out = ODATAIN;
            end
        endcase
    end

    assign CASC_OUT = casc_out_internal;

    // -------------------------------------------------------------------------
    // 4. Behavioral Delay
    // -------------------------------------------------------------------------
    real current_delay_ps;
    
    always_comb begin
        current_delay_ps = (tap_count * 5.0) + DELAY_VALUE; 
    end

    assign #(current_delay_ps * 1ps) DATAOUT = data_mux_out;

endmodule
