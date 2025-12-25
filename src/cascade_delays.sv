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
    input   logic                           in,
    input   logic [Nmbr_cascades*2-1:0]     select,
    output  logic                           out
);

    genvar g;
    generate
        logic  delay_1buf [Nmbr_cascades-1:0];
        logic  delay_2buf [Nmbr_cascades-1:0];
        logic  mux_out [Nmbr_cascades-2:0];
        
        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            case(g)
                0: begin
                    // Удалены буферы, оставлены только соединения
                    assign delay_1buf[0] = in;
                    assign delay_2buf[0] = delay_1buf[0];
                    
                    // Трёхвходовой мультиплексор
                    // I2 - прямая линия (без буферов)
                    // I1 - линия с 1 буфером
                    // I0 - линия с 2 буферами
                    MUX3V4_140P9T30R mux_inst (
                        .I2(delay_2buf[0]),
                        .I1(delay_1buf[0]),
                        .I0(in),
                        .S0(select[g*2]),
                        .S1(select[g*2+1]),
                        .Z(mux_out[0])
                    );
                end
                Nmbr_cascades-1: begin
                    // Удалены буферы, оставлены только соединения
                    assign delay_1buf[g] = mux_out[g-1];
                    assign delay_2buf[g] = delay_1buf[g];
                    
                    MUX3V4_140P9T30R mux_inst (
                        .I2(delay_2buf[g]),
                        .I1(delay_1buf[g]),
                        .I0(mux_out[g-1]),
                        .S0(select[g*2]),
                        .S1(select[g*2+1]),
                        .Z(out)
                    );
                end
                default: begin
                    // Удалены буферы, оставлены только соединения
                    assign delay_1buf[g] = mux_out[g-1];
                    assign delay_2buf[g] = delay_1buf[g];
                    
                    MUX3V4_140P9T30R mux_inst (
                        .I2(delay_2buf[g]),
                        .I1(delay_1buf[g]),
                        .I0(mux_out[g-1]),
                        .S0(select[g*2]),
                        .S1(select[g*2+1]),
                        .Z(mux_out[g])
                    );
                end
            endcase
        end : DELAY_STAGES

    endgenerate
    
endmodule