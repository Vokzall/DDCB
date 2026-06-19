//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 18/12/2025 16:15:00 PM
// Design Name:
// Module Name: IDELAYE3
// Project Name: DDCB

`define Nmbr_cascades 12
`timescale 1ns/1ps

module IDELAYE3 #(
    parameter CASCADE = "NONE",
    parameter DELAY_FORMAT = "TIME",
    parameter DELAY_SRC = "IDATAIN",
    parameter DELAY_TYPE = "VARIABLE",
    parameter DELAY_VALUE = 1'd0,
    parameter real REFCLK_FREQUENCY = 200.0,
    parameter SIM_DEVICE = "ULTRASCALE",
    parameter UPDATE_MODE = "ASYNC",
    parameter IS_CLK_INVERTED  = 1'b0,
    parameter IS_RST_INVERTED  = 1'b0
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
logic [8:0] CNTVALUEOUT;
`ifndef Nmbr_cascades
    `define Nmbr_cascades 12
`endif

    logic [`Nmbr_cascades*2-1:0] select;

    cascade_delays cascade_delays_instance (
        .in(IDATAIN),
        .select(select),
        .out(DATAOUT)
    );

    // MUX3 truth: S1=0,S0=0->I0(3DEL) | S1=0,S0=1->I1(1DEL) | S1=1,S0=0->I2(0DEL)
    // Select encoding per stage: 00=3DEL, 01=1DEL, 10=0DEL
    // Pattern: MSB(stage11) ... LSB(stage0), 2 bits per stage
    localparam logic [23:0] SELECT_LUT [0:31] = '{
        24'b101010101010101010101010,  // step  0: DEL= 0  typ_avg=306 ps
        24'b101010101010101010101001,  // step  1: DEL= 1  typ_avg=352 ps
        24'b011010101010101010101001,  // step  2: DEL= 2  typ_avg=399 ps
        24'b010110101010101010101001,  // step  3: DEL= 3  typ_avg=446 ps
        24'b000110101010101010101001,  // step  4: DEL= 5  typ_avg=511 ps
        24'b100101010101101010101010,  // step  5: DEL= 5  typ_avg=542 ps
        24'b100101010101011010101010,  // step  6: DEL= 6  typ_avg=588 ps
        24'b000001101010101010101001,  // step  7: DEL= 8  typ_avg=623 ps
        24'b000001011010101010101001,  // step  8: DEL= 9  typ_avg=670 ps
        24'b000001010110101010101001,  // step  9: DEL=10  typ_avg=717 ps
        24'b000101010101011010101001,  // step 10: DEL=10  typ_avg=746 ps
        24'b100000000101011010101010,  // step 11: DEL=12  typ_avg=784 ps
        24'b100000010101010101101010,  // step 12: DEL=12  typ_avg=812 ps
        24'b010101010101010101010101,  // step 13: DEL=12  typ_avg=869 ps
        24'b100000000101010101011010,  // step 14: DEL=15  typ_avg=924 ps
        24'b100000000000010110101010,  // step 15: DEL=17  typ_avg=960 ps
        24'b100000000001010101011010,  // step 16: DEL=17  typ_avg=990 ps
        24'b100000000000000110101010,  // step 17: DEL=19  typ_avg=1026 ps
        24'b000000000101010101011001,  // step 18: DEL=19  typ_avg=1082 ps
        24'b000000000101010101010101,  // step 19: DEL=20  typ_avg=1129 ps
        24'b000000000000010101101001,  // step 20: DEL=22  typ_avg=1165 ps
        24'b000000000001010101010101,  // step 21: DEL=22  typ_avg=1194 ps
        24'b000000000000000101101001,  // step 22: DEL=24  typ_avg=1230 ps
        24'b000000000000010101010101,  // step 23: DEL=24  typ_avg=1259 ps
        24'b000000000000000001101001,  // step 24: DEL=26  typ_avg=1295 ps
        24'b000000000000000101010101,  // step 25: DEL=26  typ_avg=1324 ps
        24'b000000000000000001010101,  // step 26: DEL=28  typ_avg=1389 ps
        24'b100000000000000000000010,  // step 27: DEL=30  typ_avg=1426 ps
        24'b000000000000000000000110,  // step 28: DEL=31  typ_avg=1473 ps
        24'b000000000000000000000010,  // step 29: DEL=33  typ_avg=1538 ps
        24'b000000000000000000000001,  // step 30: DEL=34  typ_avg=1584 ps
        24'b000000000000000000000000   // step 31: DEL=36  typ_avg=1649 ps
    };

// Clock and reset synchronization logic

    logic clk_int;
    logic rst_int;
    logic RST_sync1, RST_sync2, RST_sync3;
    logic clk_gated;

    assign clk_int = IS_CLK_INVERTED ? ~CLK : CLK;
    assign rst_int = IS_RST_INVERTED ? ~RST : RST;

    always_ff @(posedge clk_int or posedge rst_int) begin
        if (rst_int) begin
            RST_sync1 <= 1'b1;
            RST_sync2 <= 1'b1;
            RST_sync3 <= 1'b1;
        end else begin
            RST_sync1 <= 1'b0;
            RST_sync2 <= RST_sync1;
            RST_sync3 <= RST_sync2;
        end
    end


    assign clk_gated = clk_int & ~rst_int & ~RST_sync1 & ~RST_sync2 & ~RST_sync3;
//________________________________________________________

    always_ff @(posedge clk_gated, posedge rst_int) begin : COUNTER_PROC
        if (rst_int) begin
            CNTVALUEOUT <= (DELAY_VALUE == 312) ? 9'd112 : 9'd0;  // step 7: typ_avg=623 ps (~306+312)
        end
        else if (CE && !EN_VTC) begin
            CNTVALUEOUT <= (INC) ? CNTVALUEOUT + 9'd1 : CNTVALUEOUT - 9'd1;
        end
    end : COUNTER_PROC

    logic [4:0] select_idx;

    always_comb begin
        select_idx = CNTVALUEOUT[8:4];
        select = SELECT_LUT[select_idx];
    end


endmodule
