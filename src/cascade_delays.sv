//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 03/12/2025 16:15:00 PM
// Design Name:
// Module Name: cascade_delays
// Project Name: DDCB   

`timescale 1ns/1ps
`ifndef Nmbr_cascades
    `define Nmbr_cascades 11
`endif
module cascade_delays
#(Nmbr_cascades = `Nmbr_cascades)
(
    input   logic                           in,
    input   logic [Nmbr_cascades*2-1:0]     select,
    output  logic                           out
);

    genvar g;
    generate
        logic  del1_out [Nmbr_cascades-1:0];
        logic  del2_out [Nmbr_cascades-1:0];
        logic  del3_out [Nmbr_cascades-1:0];
        logic  mux_out  [Nmbr_cascades-2:0];

        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            logic stage_in;
            if (g == 0) begin : genblk_in
                assign stage_in = in;
            end else begin : genblk_in
                assign stage_in = mux_out[g-1];
            end

            // del1 — общий для I1 и I0
            DEL1V4_140P9T30R del1_inst (
                .I (stage_in),
                .Z (del1_out[g])
            );

            // del2 — только для I0
            DEL1V4_140P9T30R del2_inst (
                .I (del1_out[g]),
                .Z (del2_out[g])
            );

            // del3 — только для I0
            DEL1V4_140P9T30R del3_inst (
                .I (del2_out[g]),
                .Z (del3_out[g])
            );

            // I2 - прямой провод                    (0 DEL1V4)
            // I1 - del1_out                          (1 DEL1V4)
            // I0 - del1_out -> del2_out -> del3_out  (3 DEL1V4)
            if (g == Nmbr_cascades - 1) begin : genblk_mux
                MUX3V4_140P9T30R mux_inst (
                    .I2(stage_in),
                    .I1(del1_out[g]),
                    .I0(del3_out[g]),
                    .S0(select[g*2]),
                    .S1(select[g*2+1]),
                    .Z(out)
                );
            end else begin : genblk_mux
                MUX3V4_140P9T30R mux_inst (
                    .I2(stage_in),
                    .I1(del1_out[g]),
                    .I0(del3_out[g]),
                    .S0(select[g*2]),
                    .S1(select[g*2+1]),
                    .Z(mux_out[g])
                );
            end
        end : DELAY_STAGES

    endgenerate
    
endmodule