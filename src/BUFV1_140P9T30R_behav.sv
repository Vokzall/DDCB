// Behavioral model of BUFV1_140P9T30R
// Delays from SDF (stages 1-5 typical): rise=21ps, fall=22ps

`timescale 1ns / 1ps

module BUFV1_140P9T30R (
    input  wire I,
    output reg  Z
);

    always_comb begin
        if (I)
            Z <= #0.021 I;
        else
            Z <= #0.022 I;
    end

endmodule
