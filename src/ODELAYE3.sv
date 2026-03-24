//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 18/12/2025 16:15:00 PM
// Design Name:
// Module Name: ODELAYE3
// Project Name: DDCB
//
//////////////////////////////////////////////////////////////////////////////////
//
//  ODELAYE3 Block Diagram (DELAY_VALUE == 500)
//  ============================================
//
//  First pass (first_pass_done == 0):
//  -----------------------------------
//
//                    +-------------+     +-----------------+
//    ODATAIN ------->| const_delay |---->| cascade_delays  |-----> DATAOUT
//                    | (fixed ~Xps)|     | (select[15:0])  |
//                    +-------------+     +-----------------+
//
//  After first pass (first_pass_done == 1):
//  -----------------------------------------
//
//                                        +-----------------+
//    ODATAIN -------------------------->| cascade_delays  |-----> DATAOUT
//                                        | (select[15:0])  |
//                                        +-----------------+
//
//  ODELAYE3 Block Diagram (DELAY_VALUE != 500)
//  ============================================
//
//                                        +-----------------+
//    ODATAIN -------------------------->| cascade_delays  |-----> DATAOUT
//                                        | (select[15:0])  |
//                                        +-----------------+
//
//  Control Logic:
//  --------------
//
//                  +-----+
//    CLK --------->|     |
//    RST --------->| CNT |---> cnt[8:0] (0..511, 512 steps)
//    CE  --------->|     |---> CNTVALUEOUT[8:0]
//    INC --------->|     |
//    EN_VTC ------>+-----+
//                     |
//                     v  (select_idx = cnt / 32)
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

module ODELAYE3 #(
    parameter CASCADE = "NONE",
    parameter DELAY_FORMAT = "TIME",
    parameter DELAY_TYPE = "VARIABLE",
    parameter DELAY_VALUE = 1'd0,
    parameter real REFCLK_FREQUENCY = 200.0,
    parameter SIM_DEVICE = "ULTRASCALE",
    parameter UPDATE_MODE = "ASYNC"
) (
    // Inputs
    input wire CE,
    input wire CLK,
    input wire EN_VTC,
    input wire ODATAIN,
    input wire INC,
    input wire RST,
    // Outputs
    output wire DATAOUT,
    output wire [8:0] CNTVALUEOUT
);

    // SELECT lookup table (16 entries, 16 bits each)
    // CNT 0 = minimum delay (all I2), CNT 15 = stg7=I1 (near max)
    // Counter counts 0..511, select changes every 32 counts (select_idx = cnt / 32)
    // Encoding per stage pair (MSB-first):
    //   "00" -> I0+buf (slowest), "10" -> I1 (medium), "01" -> I2 (fastest)

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

    localparam CNT_WIDTH = 9;
    localparam CNT_MAX = 511;

    // Calculate initial count from DELAY_VALUE (matching Xilinx ODELAYE3 behavior)
    // DELAY_FORMAT="TIME": DELAY_VALUE is in ps, each tap ≈ 5ps → count = DELAY_VALUE/5
    // DELAY_FORMAT="COUNT": DELAY_VALUE is the count directly
    localparam [CNT_WIDTH-1:0] CNT_INIT = (DELAY_FORMAT == "TIME") ?
        (DELAY_VALUE / 5) : DELAY_VALUE;

    logic [CNT_WIDTH-1:0] cnt;
    logic [3:0] select_idx;
    logic [15:0] select;

    // First pass tracking for const_delay inclusion
    logic first_pass_done;

    // Internal signal after const_delay
    wire after_const_delay;
    wire cascade_input;

    // select_idx = cnt / 32 (32 taps per delay level, 16 levels total)
    assign select_idx = cnt[8:5];

    // Lookup select value from table
    assign select = SELECT_LUT[select_idx];

    // CNTVALUEOUT mirrors cnt (9'bxxxxxxxxx when EN_VTC=1, per Xilinx spec)
    assign CNTVALUEOUT = EN_VTC ? 9'bxxxxxxxxx : cnt;

    // Const delay instantiation (only used when DELAY_VALUE == 500)
    generate
        if (DELAY_VALUE == 500) begin : gen_const_delay
            const_delay const_delay_inst (
                .I(ODATAIN),
                .O(after_const_delay)
            );
            // MUX: use const_delay output on first pass, bypass after
            assign cascade_input = first_pass_done ? ODATAIN : after_const_delay;
        end else begin : gen_no_const_delay
            assign cascade_input = ODATAIN;
        end
    endgenerate

    // Cascade delays instantiation
    cascade_delays #(.Nmbr_cascades(8)) cascade_delays_inst (
        .in(cascade_input),
        .select(select),
        .out(DATAOUT)
    );

    // Counter and control logic
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            cnt <= CNT_INIT;
            first_pass_done <= (DELAY_VALUE == 500) ? 1'b0 : 1'b1;
        end else if (CE && !EN_VTC) begin
            if (INC) begin
                // Increment
                if (cnt == CNT_MAX[CNT_WIDTH-1:0]) begin
                    cnt <= '0;
                    first_pass_done <= 1'b1;  // First pass completed
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
