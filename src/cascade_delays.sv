//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 03/12/2025 16:15:00 PM
// Design Name:
// Module Name: cascade_delays
// Project Name: DDCB
// Architecture: Ladder - single buffer at input, cascade of 2-input muxes
//          ┌──[BUF]──┐
//          │         │
// in ──────┤         ├──[MUX0]──[MUX1]──[MUX2]──[MUX3]── out
//          │         │     ▲       ▲       ▲       ▲
//          └─────────┘     │       │       │       │
//                       in─┴───────┴───────┴───────┘

`timescale 1ns/1ps
`ifndef Nmbr_cascades
    `define Nmbr_cascades 4
`endif
module cascade_delays
#(Nmbr_cascades = `Nmbr_cascades)
(
    input   logic                       in,
    input   logic [Nmbr_cascades-1:0]   select,
    output  logic                       out
);

    logic in_buffered;
    logic mux_out [Nmbr_cascades-1:0];
    
    // Single buffer at the input
    BUFV1_140P9T30R input_buffer (
        .I(in),
        .Z(in_buffered)
    );

    genvar g;
    generate
        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            if (g == 0) begin
                // First mux: select between direct input and buffered input
                CLKMUX2V0_140P9T30R mux_inst (
                    .I0(in),
                    .I1(in_buffered),
                    .S(select[0]),
                    .Z(mux_out[0])
                );
            end else if (g == Nmbr_cascades-1) begin
                // Last mux: select between previous mux output and direct input
                CLKMUX2V0_140P9T30R mux_inst (
                    .I0(mux_out[g-1]),
                    .I1(in),
                    .S(select[g]),
                    .Z(out)
                );
            end else begin
                // Intermediate muxes: select between previous mux output and direct input
                CLKMUX2V0_140P9T30R mux_inst (
                    .I0(mux_out[g-1]),
                    .I1(in),
                    .S(select[g]),
                    .Z(mux_out[g])
                );
            end
        end : DELAY_STAGES
    endgenerate
    
endmodule