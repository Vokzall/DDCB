`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
//
// Create Date: 09/28/2023 02:15:00 PM
// Design Name:
// Module Name: muxed_delays
// Project Name: DDCB

module muxed_delays #(
    parameter INPUTS = 4
)
(
    input logic [INPUTS-1:0] delay_lines,
    input logic [$clog2(INPUTS)-1:0] select,
    output logic out
);

    
    // Mux to select the desired delay line
    // genvar i;
    // generate
    //     for(i = 0; i < INPUTS; i++) begin : delay_line_gen
    //         BUFV1_140P9T30R delay_inst (
    //             .I(in),
    //             .Z(delay_lines[i])
    //         );
    //     end : delay_line_gen
    // endgenerate

    assign out = delay_lines[select];
    
endmodule
