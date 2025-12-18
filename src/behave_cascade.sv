// 1. 000000 (0x00)
// 2. 000001 (0x01)
// 3. 000011 (0x03)
// 4. 000111 (0x07)
// 5. 001111 (0x0F)
// 6. 011111 (0x1F)
// 7. 111111 (0x3F)

// Rise:
// [170, 184, 198, 211, 225, 239, 252] ps

// Fall:
// [165, 177, 190, 202, 215, 227, 240] ps



`timescale 1ns / 1ps
`define GLS
module cascade_delays (
    input wire in,
    input wire [5:0] select,
    output reg out
);

    // Внутренние сигналы для отслеживания задержек
    reg [5:0] delay_in;
    reg [4:0] delay_out;
    
    // Stage 0: Buffer delay + Mux delay
    // Buffer: I -> delay_in[0], delays: 15ps rise, 14ps fall
    always @(in) begin
        if (in == 1'b1)
            delay_in[0] <= #0.015 in;  // Rise
        else
            delay_in[0] <= #0.014 in;  // Fall
    end
    
    // Mux: I0=in (direct), I1=delay_in[0] (delayed), S=select[0], Z=delay_out[0]
    // When S=0: output = I0 (direct path)
    // When S=1: output = I1 (delayed path)
    always @(in or delay_in[0] or select[0]) begin
        if (select[0] == 1'b0) begin
            // I0 path (direct): 28ps rise, 26ps fall
            if (in == 1'b1)
                delay_out[0] <= #0.028 in;
            else
                delay_out[0] <= #0.026 in;
        end else begin
            // I1 path (delayed): 27ps rise, 24ps fall
            if (delay_in[0] == 1'b1)
                delay_out[0] <= #0.027 delay_in[0];
            else
                delay_out[0] <= #0.024 delay_in[0];
        end
    end
    
    // Stage 1: Buffer delay + Mux delay
    always @(delay_out[0]) begin
        delay_in[1] <= #0.016 delay_out[0];
    end
    
    // Mux: I0=delay_out[0] (direct), I1=delay_in[1] (delayed), S=select[1]
    always @(delay_out[0] or delay_in[1] or select[1]) begin
        if (select[1] == 1'b0) begin
            // I0 path (direct): 29ps rise, 28ps fall
            if (delay_out[0] == 1'b1)
                delay_out[1] <= #0.029 delay_out[0];
            else
                delay_out[1] <= #0.028 delay_out[0];
        end else begin
            // I1 path (delayed): 27ps rise, 24ps fall
            if (delay_in[1] == 1'b1)
                delay_out[1] <= #0.027 delay_in[1];
            else
                delay_out[1] <= #0.024 delay_in[1];
        end
    end
    
    // Stage 2: Buffer delay + Mux delay
    always @(delay_out[1]) begin
        delay_in[2] <= #0.016 delay_out[1];
    end
    
    always @(delay_out[1] or delay_in[2] or select[2]) begin
        if (select[2] == 1'b0) begin
            // I0 path (direct): 29ps rise, 28ps fall
            if (delay_out[1] == 1'b1)
                delay_out[2] <= #0.029 delay_out[1];
            else
                delay_out[2] <= #0.028 delay_out[1];
        end else begin
            // I1 path (delayed): 27ps rise, 24ps fall
            if (delay_in[2] == 1'b1)
                delay_out[2] <= #0.027 delay_in[2];
            else
                delay_out[2] <= #0.024 delay_in[2];
        end
    end
    
    // Stage 3: Buffer delay + Mux delay
    always @(delay_out[2]) begin
        delay_in[3] <= #0.016 delay_out[2];
    end
    
    always @(delay_out[2] or delay_in[3] or select[3]) begin
        if (select[3] == 1'b0) begin
            // I0 path (direct): 29ps rise, 28ps fall
            if (delay_out[2] == 1'b1)
                delay_out[3] <= #0.029 delay_out[2];
            else
                delay_out[3] <= #0.028 delay_out[2];
        end else begin
            // I1 path (delayed): 27ps rise, 24ps fall
            if (delay_in[3] == 1'b1)
                delay_out[3] <= #0.027 delay_in[3];
            else
                delay_out[3] <= #0.024 delay_in[3];
        end
    end
    
    // Stage 4: Buffer delay + Mux delay
    always @(delay_out[3]) begin
        delay_in[4] <= #0.016 delay_out[3];
    end
    
    always @(delay_out[3] or delay_in[4] or select[4]) begin
        if (select[4] == 1'b0) begin
            // I0 path (direct): 29ps rise, 28ps fall
            if (delay_out[3] == 1'b1)
                delay_out[4] <= #0.029 delay_out[3];
            else
                delay_out[4] <= #0.028 delay_out[3];
        end else begin
            // I1 path (delayed): 27ps rise, 24ps fall
            if (delay_in[4] == 1'b1)
                delay_out[4] <= #0.027 delay_in[4];
            else
                delay_out[4] <= #0.024 delay_in[4];
        end
    end
    
    // Stage 5: Buffer delay + Mux delay (последний каскад с другими задержками)
    always @(delay_out[4]) begin
        delay_in[5] <= #0.016 delay_out[4];
    end
    
    // Mux: I0=delay_out[4] (direct), I1=delay_in[5] (delayed), S=select[5], Z=out
    always @(delay_out[4] or delay_in[5] or select[5]) begin
        if (select[5] == 1'b0) begin
            // I0 path (direct): 22ps (both rise and fall)
            out <= #0.022 delay_out[4];
        end else begin
            // I1 path (delayed): 20ps rise, 19ps fall
            if (delay_in[5] == 1'b1)
                out <= #0.020 delay_in[5];
            else
                out <= #0.019 delay_in[5];
        end
    end

endmodule