//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 18/12/2025 16:15:00 PM
// Design Name:
// Module Name: IDELAYE3
// Project Name: DDCB
//
//////////////////////////////////////////////////////////////////////////////////
//
//  IDELAYE3 Block Diagram
//  ======================
//
//                                        +-----------------+
//    IDATAIN -------------------------->| cascade_delays  |-----> DATAOUT
//                                        | (select[9:0])   |
//                                        +-----------------+
//
//  Control Logic:
//  --------------
//
//                  +-----+
//    CLK --------->|     |
//    RST --------->| CNT |---> cnt[3:0] (or cnt[8:0] in SLOW_COUNT mode)
//    CE  --------->|     |
//    INC --------->|     |
//    EN_VTC ------>+-----+
//                     |
//                     v
//              +------------+
//              | SELECT LUT |---> select[9:0]
//              +------------+
//
//  Architecture: 5-stage MUX3 cascade with buffer on I0
//    Per stage: BUFV1 -> I0, direct -> I1, direct -> I2
//    select pair encoding (MSB-first in 10-bit literal):
//      "00" -> {S1,S0}=00 -> I0 (buf, slowest)
//      "10" -> {S1,S0}=01 -> I1 (direct, medium)
//      "01" -> {S1,S0}=10 -> I2 (direct, fastest)
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module IDELAYE3 #(
    parameter CASCADE = "NONE",
    parameter DELAY_FORMAT = "TIME",
    parameter DELAY_SRC = "IDATAIN",
    parameter DELAY_TYPE = "VARIABLE",
    parameter DELAY_VALUE = 1'd0,
    parameter IS_CLK_INVERTED = 1'd0,
    parameter IS_RST_INVERTED = 1'd0,
    parameter real REFCLK_FREQUENCY = 200.0,
    parameter SIM_DEVICE = "ULTRASCALE",
    parameter UPDATE_MODE = "ASYNC"
) (
    // Inputs
    input wire CE,
    input wire CLK,
    input wire EN_VTC,
    input wire IDATAIN,
    input wire INC,
    input wire RST,
    // Outputs
    output wire DATAOUT
);

    // SELECT lookup table (12 entries, 10 bits each)
    // CNT 0 = minimum delay (all I2), CNT 10 = maximum delay (all I0+buf)
    // Delay increases with CNT increment. Entry 11 = duplicate of 10 (saturated).

    localparam logic [9:0] SELECT_LUT [0:11] = '{
        10'b01_01_01_01_01,  // CNT 0:  all I2 (min delay)  Rise=135, Fall=129
        10'b01_01_01_01_10,  // CNT 1:  stg0=I1             Rise=148, Fall=143
        10'b01_01_01_01_00,  // CNT 2:  stg0=I0+buf         Rise=168, Fall=164
        10'b01_01_01_10_00,  // CNT 3:  +stg1=I1            Rise=180, Fall=178
        10'b01_01_01_00_00,  // CNT 4:  +stg1=I0+buf        Rise=200, Fall=198
        10'b01_01_10_00_00,  // CNT 5:  +stg2=I1            Rise=213, Fall=212
        10'b01_01_00_00_00,  // CNT 6:  +stg2=I0+buf        Rise=233, Fall=233
        10'b01_10_00_00_00,  // CNT 7:  +stg3=I1            Rise=245, Fall=247
        10'b01_00_00_00_00,  // CNT 8:  +stg3=I0+buf        Rise=265, Fall=268
        10'b10_00_00_00_00,  // CNT 9:  +stg4=I1            Rise=277, Fall=280
        10'b00_00_00_00_00,  // CNT 10: all I0+buf (max)    Rise=296, Fall=300
        10'b00_00_00_00_00   // CNT 11: same as 10 (saturated)
    };

`ifdef SLOW_COUNT
    localparam CNT_WIDTH = 9;
    localparam CNT_MAX = 511;
`else
    localparam CNT_WIDTH = 4;
    localparam CNT_MAX = 11;
`endif

    logic [CNT_WIDTH-1:0] cnt;
    logic [3:0] select_idx;
    logic [9:0] select;

    // Calculate select index from counter
`ifdef SLOW_COUNT
    assign select_idx = cnt[CNT_WIDTH-1:5];  // cnt / 32
`else
    assign select_idx = cnt;
`endif

    // Lookup select value from table (clamp to 11)
    assign select = SELECT_LUT[(select_idx > 4'd11) ? 4'd11 : select_idx];

    // Cascade delays instantiation
    cascade_delays #(.Nmbr_cascades(5)) cascade_delays_inst (
        .in(IDATAIN),
        .select(select),
        .out(DATAOUT)
    );

    // Counter and control logic
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            cnt <= '0;
        end else if (CE && !EN_VTC) begin
            if (INC) begin
                // Increment
                if (cnt == CNT_MAX[CNT_WIDTH-1:0]) begin
                    cnt <= '0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end else begin
                // Decrement
                if (cnt == '0) begin
                    cnt <= CNT_MAX[CNT_WIDTH-1:0];
                end else begin
                    cnt <= cnt - 1'b1;
                end
            end
        end
    end

endmodule
