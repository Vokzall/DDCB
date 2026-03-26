//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 18/12/2025 16:15:00 PM
// Design Name:
// Module Name: ODELAYE3
// Project Name: DDCB  

// 1. 000000 (0x00)
// 2. 000001 (0x01)
// 3. 000011 (0x03)
// 4. 000111 (0x07)
// 5. 001111 (0x0F)
// 6. 011111 (0x1F)
// 7. 111111 (0x3F)

// Rise:
// [170, 184, 198, 211, 225, 239, 252] ps

// Fall:
// [165, 177, 190, 202, 215, 227, 240] ps

`define Nmbr_cascades 11
`timescale 1ns/1ps

module ODELAYE3 #(
    parameter CASCADE = "NONE",
    parameter DELAY_FORMAT = "TIME",
    parameter DELAY_TYPE = "VARIABLE",
    parameter DELAY_VALUE = 0,
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
    input wire ODATAIN,
    input wire INC,
    input wire RST,
    // Outputs
    output wire DATAOUT,
    output logic [8:0] CNTVALUEOUT
);

`ifndef Nmbr_cascades
    `define Nmbr_cascades 6
`endif

    logic [`Nmbr_cascades*2-1:0] select;

    cascade_delays cascade_delays_netlist (
        .in(ODATAIN),
        .select(select),
        .out(DATAOUT)
    );
    // MUX3 truth: S1=0,S0=0->I0(3DEL) | S1=0,S0=1->I1(1DEL) | S1=1,S0=0->I2(0DEL)
    // Select encoding per stage: 00=3DEL, 01=1DEL, 10=0DEL
    // Pattern: MSB(stage10) ... LSB(stage0), 2 bits per stage
    localparam logic [21:0] SELECT_LUT [0:31] = '{
        22'b1010101010101010101010,  // step  0:  0 DEL — all I2
        22'b1010101010101010101001,  // step  1:  1 DEL
        22'b1010101010101010100101,  // step  2:  2 DEL
        22'b1010101010101010101000,  // step  3:  3 DEL
        22'b1010101010101010100100,  // step  4:  4 DEL
        22'b1010101010101010010100,  // step  5:  5 DEL
        22'b1010101010101010100000,  // step  6:  6 DEL
        22'b1010101010101010010000,  // step  7:  7 DEL
        22'b1010101010101001010000,  // step  8:  8 DEL
        22'b1010101010101010000000,  // step  9:  9 DEL
        22'b1010101010101001000000,  // step 10: 10 DEL
        22'b1010101010100101000000,  // step 11: 11 DEL
        22'b1010101010101000000000,  // step 12: 12 DEL
        22'b1010101010100100000000,  // step 13: 13 DEL
        22'b1010101010010100000000,  // step 14: 14 DEL
        22'b1010101010100000000000,  // step 15: 15 DEL
        22'b1010101010010000000000,  // step 16: 16 DEL
        22'b1010101001010000000000,  // step 17: 17 DEL
        22'b1010101010000000000000,  // step 18: 18 DEL
        22'b1010101001000000000000,  // step 19: 19 DEL
        22'b1010100101000000000000,  // step 20: 20 DEL
        22'b1010101000000000000000,  // step 21: 21 DEL
        22'b1010100100000000000000,  // step 22: 22 DEL
        22'b1010010100000000000000,  // step 23: 23 DEL
        22'b1010100000000000000000,  // step 24: 24 DEL
        22'b1010010000000000000000,  // step 25: 25 DEL
        22'b1001010000000000000000,  // step 26: 26 DEL
        22'b1010000000000000000000,  // step 27: 27 DEL
        22'b1001000000000000000000,  // step 28: 28 DEL
        22'b0101000000000000000000,  // step 29: 29 DEL
        22'b1000000000000000000000,  // step 30: 30 DEL
        22'b0100000000000000000000   // step 31: 31 DEL
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
            CNTVALUEOUT <= (DELAY_VALUE == 500) ? 9'd160 : 9'd0;
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