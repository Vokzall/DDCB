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
//                    | (fixed ~Xps)|     | (select[9:0])   |
//                    +-------------+     +-----------------+
//
//  After first pass (first_pass_done == 1):
//  -----------------------------------------
//
//                                        +-----------------+
//    ODATAIN -------------------------->| cascade_delays  |-----> DATAOUT
//                                        | (select[9:0])   |
//                                        +-----------------+
//
//  ODELAYE3 Block Diagram (DELAY_VALUE != 500)
//  ============================================
//
//                                        +-----------------+
//    ODATAIN -------------------------->| cascade_delays  |-----> DATAOUT
//                                        | (select[9:0])   |
//                                        +-----------------+
//
//  Control Logic:
//  --------------
//
//                  +-----+
//    CLK --------->|     |
//    RST --------->| CNT |---> cnt[3:0] (or cnt[8:0] in SLOW_COUNT mode)
//    CE  --------->|     |---> CNTVALUEOUT[8:0]
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

    // SELECT lookup table (11 entries, 10 bits each)
    // CNT 0 = minimum delay (all I2), CNT 10 = maximum delay (all I0+buf)
    // Delay increases with CNT increment.
    // Encoding per stage pair (MSB-first):
    //   "00" -> I0+buf (slowest), "10" -> I1 (medium), "01" -> I2 (fastest)

    localparam logic [9:0] SELECT_LUT [0:10] = '{
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
        10'b00_00_00_00_00   // CNT 10: all I0+buf (max)    Rise=296, Fall=300
    };

`ifdef SLOW_COUNT
    localparam CNT_WIDTH = 9;
    localparam CNT_MAX = 511;
`else
    localparam CNT_WIDTH = 4;
    localparam CNT_MAX = 10;
`endif

    logic [CNT_WIDTH-1:0] cnt;
    logic [3:0] select_idx;
    logic [9:0] select;

    // First pass tracking for const_delay inclusion
    logic first_pass_done;

    // Internal signal after const_delay
    wire after_const_delay;
    wire cascade_input;

    // Calculate select index from counter
`ifdef SLOW_COUNT
    assign select_idx = cnt[CNT_WIDTH-1:5];  // cnt / 32
`else
    assign select_idx = cnt;
`endif

    // Lookup select value from table (clamp to 10)
    assign select = SELECT_LUT[(select_idx > 4'd10) ? 4'd10 : select_idx];

    // CNTVALUEOUT mirrors cnt
    assign CNTVALUEOUT = {5'd0, cnt[3:0]};

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
    cascade_delays #(.Nmbr_cascades(5)) cascade_delays_inst (
        .in(cascade_input),
        .select(select),
        .out(DATAOUT)
    );

    // Counter and control logic
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            cnt <= '0;
            first_pass_done <= 1'b0;
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
