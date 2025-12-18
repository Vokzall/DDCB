//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 18/12/2025 16:15:00 PM
// Design Name:
// Module Name: IDELAYE3
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

`define Nmbr_cascades 6
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
    output logic [8:0] CNTVALUEOUT
);

`ifndef Nmbr_cascades
    `define Nmbr_cascades 6
`endif

    logic [`Nmbr_cascades-1:0] select;

    cascade_delays 
`ifndef GLS    
    #(
        .Nmbr_cascades(`Nmbr_cascades)
    )
`endif
    cascade_delays_instance (
        .in(ODATAIN),
        .select(select),
        .out(DATAOUT)
    );
    
    
    always_ff @(posedge CLK or posedge RST) begin : COUNTER_PROC
        if (RST) begin 
            select      <= `Nmbr_cascades'd0;
            CNTVALUEOUT <= 9'd0;
        end
        else if (CE && !EN_VTC) begin 
            select      <= (INC) ? {select[`Nmbr_cascades-2:0], 1'b1} : {1'b0, select[`Nmbr_cascades-1:1]};
            CNTVALUEOUT <= (INC) ? CNTVALUEOUT + 9'd1 : CNTVALUEOUT - 9'd1;
        end
    end : COUNTER_PROC
    

endmodule