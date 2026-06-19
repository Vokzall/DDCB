//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Module Name: const_delay
// Project Name: DDCB
//
// Pure series chain of Nmbr_cascades delay cells (no muxes, no select).
// Used as a constant-delay reference line for per-cell delay characterization.

`timescale 1ns/1ps
`ifndef Nmbr_cascades
    `define Nmbr_cascades 11
`endif
module const_delay
#(Nmbr_cascades = `Nmbr_cascades)
(
    input   logic   in,
    output  logic   out
);

    genvar g;
    generate
        logic chain [Nmbr_cascades:0];
        assign chain[0] = in;

        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            DEL2V0_140P9T30R u_delay_inst (
                .I (chain[g]),
                .Z (chain[g+1])
            );
        end : DELAY_STAGES

        assign out = chain[Nmbr_cascades];
    endgenerate

endmodule
