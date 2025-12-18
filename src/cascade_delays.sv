//////////////////////////////////////////////////////////////////////////////////
// Company: RISCY
// Engineer: Muzalevskiy
// Create Date: 03/12/2025 16:15:00 PM
// Design Name:
// Module Name: cascade_delays
// Project Name: DDCB   

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

    genvar g;
    generate
        logic  delay_in [Nmbr_cascades-1:0];
        logic  delay_out [Nmbr_cascades-2:0];
        

        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            case(g)
                0: begin
                    BUFV1_140P9T30R delay_inst (
                        .I(in),
                        .Z(delay_in[0])
                    );
                    CLKMUX2V0_140P9T30R mux_inst (
                        .I1(delay_in[0]),
                        .I0(in),
                        .S(select[0]),
                        .Z(delay_out[0])
                    );
                end
                Nmbr_cascades-1: begin
                    BUFV1_140P9T30R delay_inst (
                        .I(delay_out[g-1]),
                        .Z(delay_in[g])
                    );
                    CLKMUX2V0_140P9T30R mux_inst (
                        .I1(delay_in[g]),
                        .I0(delay_out[g-1]),
                        .S(select[g]),
                        .Z(out)
                    );
                end
                default: begin
                    BUFV1_140P9T30R delay_inst (
                        .I(delay_out[g-1]),
                        .Z(delay_in[g])
                    );
                    CLKMUX2V0_140P9T30R mux_inst (
                        .I1(delay_in[g]),
                        .I0(delay_out[g-1]),
                        .S(select[g]),
                        .Z(delay_out[g])
                    );
                end
            endcase
        end : DELAY_STAGES

    endgenerate
    
endmodule