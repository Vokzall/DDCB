//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 03/12/2025 16:15:00 PM
// Design Name:
// Module Name: cascade_delays
// Project Name: DDCB
//
// Architecture: MUX3 cascade with buffer on I0
//   Each stage: BUFV1_140P9T30R -> I0, direct -> I1, direct -> I2
//   {S1,S0}=00 -> I0 (through buffer, slowest)
//   {S1,S0}=01 -> I1 (direct, medium)
//   {S1,S0}=10 -> I2 (direct, fastest)
//   Select bus: 2 bits per stage.

`timescale 1ns/1ps
`ifndef Nmbr_cascades
    `define Nmbr_cascades 7
`endif
module cascade_delays
#(Nmbr_cascades = `Nmbr_cascades)
(
    input   logic                           in,
    input   logic [2*Nmbr_cascades-1:0]     select,
    output  logic                           out
);

    genvar g;
    generate
        logic mux_out [Nmbr_cascades-2:0];
        logic buf_out [Nmbr_cascades-1:0];

        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            if (g == 0) begin
                BUFV1_140P9T30R buf_inst (
                    .I(in),
                    .Z(buf_out[0])
                );
                MUX3V4_140P9T30R mux_inst (
                    .I0(buf_out[0]),
                    .I1(in),
                    .I2(in),
                    .S0(select[1]),
                    .S1(select[0]),
                    .Z(mux_out[0])
                );
            end else if (g == Nmbr_cascades-1) begin
                BUFV1_140P9T30R buf_inst (
                    .I(mux_out[g-1]),
                    .Z(buf_out[g])
                );
                MUX3V4_140P9T30R mux_inst (
                    .I0(buf_out[g]),
                    .I1(mux_out[g-1]),
                    .I2(mux_out[g-1]),
                    .S0(select[2*g+1]),
                    .S1(select[2*g]),
                    .Z(out)
                );
            end else begin
                BUFV1_140P9T30R buf_inst (
                    .I(mux_out[g-1]),
                    .Z(buf_out[g])
                );
                MUX3V4_140P9T30R mux_inst (
                    .I0(buf_out[g]),
                    .I1(mux_out[g-1]),
                    .I2(mux_out[g-1]),
                    .S0(select[2*g+1]),
                    .S1(select[2*g]),
                    .Z(mux_out[g])
                );
            end
        end : DELAY_STAGES

    endgenerate

endmodule
