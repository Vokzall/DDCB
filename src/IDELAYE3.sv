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
//                                        | (select[15:0])  |
//                                        +-----------------+
//
//  Control Logic:
//  --------------
//
//                  +-----+
//    CLK --------->|     |
//    RST --------->| CNT |---> cnt[5:0] (0..63, 64 steps)
//    CE  --------->|     |
//    INC --------->|     |
//    EN_VTC ------>+-----+
//                     |
//                     v  (select_idx = cnt / 4)
//              +------------+
//              | SELECT LUT |---> select[15:0]
//              +------------+
//
//  Architecture: 8-stage MUX3 cascade with buffer on I0
//    Per stage: BUFV1 -> I0, direct -> I1, direct -> I2
//    select pair encoding (MSB-first in 16-bit literal):
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

    // SELECT lookup table (16 entries, 16 bits each)
    // CNT 0 = minimum delay (all I2), CNT 15 = stg7=I1 (near max)
    // Counter counts 0..63, select changes every 4 counts (select_idx = cnt / 4)

    localparam logic [15:0] SELECT_LUT [0:15] = '{
        16'b01_01_01_01_01_01_01_01,  // CNT 0:  all I2              Rise=218, Fall=208
        16'b01_01_01_01_01_01_01_10,  // CNT 1:  stg0=I1             Rise=231, Fall=222
        16'b01_01_01_01_01_01_01_00,  // CNT 2:  stg0=I0+buf         Rise=251, Fall=242
        16'b01_01_01_01_01_01_10_00,  // CNT 3:  +stg1=I1            Rise=264, Fall=256
        16'b01_01_01_01_01_01_00_00,  // CNT 4:  +stg1=I0+buf        Rise=283, Fall=277
        16'b01_01_01_01_01_10_00_00,  // CNT 5:  +stg2=I1            Rise=296, Fall=291
        16'b01_01_01_01_01_00_00_00,  // CNT 6:  +stg2=I0+buf        Rise=316, Fall=312
        16'b01_01_01_01_10_00_00_00,  // CNT 7:  +stg3=I1            Rise=328, Fall=326
        16'b01_01_01_01_00_00_00_00,  // CNT 8:  +stg3=I0+buf        Rise=348, Fall=347
        16'b01_01_01_10_00_00_00_00,  // CNT 9:  +stg4=I1            Rise=361, Fall=360
        16'b01_01_01_00_00_00_00_00,  // CNT 10: +stg4=I0+buf        Rise=381, Fall=381
        16'b01_01_10_00_00_00_00_00,  // CNT 11: +stg5=I1            Rise=393, Fall=395
        16'b01_01_00_00_00_00_00_00,  // CNT 12: +stg5=I0+buf        Rise=413, Fall=416
        16'b01_10_00_00_00_00_00_00,  // CNT 13: +stg6=I1            Rise=426, Fall=430
        16'b01_00_00_00_00_00_00_00,  // CNT 14: +stg6=I0+buf        Rise=445, Fall=451
        16'b10_00_00_00_00_00_00_00   // CNT 15: +stg7=I1            Rise=457, Fall=463
    };

    localparam CNT_WIDTH = 6;
    localparam CNT_MAX = 63;

    logic [CNT_WIDTH-1:0] cnt;
    logic [3:0] select_idx;
    logic [15:0] select;

    // select_idx = cnt / 4
    assign select_idx = cnt[5:2];

    // Lookup select value from table
    assign select = SELECT_LUT[select_idx];

    // Cascade delays instantiation
    cascade_delays #(.Nmbr_cascades(8)) cascade_delays_inst (
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
