`timescale 1ns/1ps

module const_delay
#(
    parameter integer Nmbr_cascades = 5
)
(
    input  logic       I,
    output logic       O
);

    genvar g;
    generate
        logic  delay_buf [Nmbr_cascades:0];
        
        for (g = 0; g < Nmbr_cascades; g++) begin : DELAY_STAGES
            DEL4V4_140P9T30R u_delay_inst (
                .I(delay_buf[g]),
                .Z(delay_buf[g+1])
            );
        end : DELAY_STAGES
    

    endgenerate
    assign O = delay_buf[Nmbr_cascades];
    assign delay_buf[0] = I;
endmodule 