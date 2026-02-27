// Behavioral model of MUX3V4_140P9T30R
// Delays from synthesis (5-stage cascade):
//
//   {S1,S0} | Selected | Rise(ps) | Fall(ps)
//   --------|----------|----------|--------
//     00    |    I0    |    38    |   38
//     01    |    I1    |    40    |   40
//     10    |    I2    |    27    |   26
//     11    |    I2    |    27    |   26

`timescale 1ns / 1ps

module MUX3V4_140P9T30R (
    input  wire I0,
    input  wire I1,
    input  wire I2,
    input  wire S0,
    input  wire S1,
    output reg  Z
);

    always_comb begin
        if(S1) begin
            if(I2) Z <= #0.027 I2;
            else   Z <= #0.026 I2;
        end else if(S0)
            Z <= #0.040 I1;
        else
            Z <= #0.038 I0;
    end

endmodule
