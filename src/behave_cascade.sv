// 1. 0000 (0x0)
// 2. 0010 (0x2)
// 3. 0011 (0x3)
// 4. 0111 (0x7)
// 5. 1111 (0xF)

// Rise:
// [169, 188, 208, 228, 248] пс

// Fall:
// [161, 179, 196, 214, 232] пс



`timescale 1ns / 1ps

module cascade_delays_behavioral(
    input wire in,
    input wire [3:0] select,
    output reg out
);

    // Внутренние сигналы для отслеживания задержек
    reg [3:0] delay_in;
    reg [2:0] delay_out;
    
    // Stage 0: Buffer delay + Mux delay
    // Buffer: I -> delay_in[0], delays: 21ps (both rise and fall)
    always @(in) begin
        delay_in[0] <= #0.021 in;
    end
    
    // Mux: I0=in (direct), I1=delay_in[0] (delayed), S=select[0], Z=delay_out[0]
    // When S=0: output = I0 (direct path)
    // When S=1: output = I1 (delayed path)
    always @(in or delay_in[0] or select[0]) begin
        if (select[0] == 1'b0) begin
            // I0 path (direct): 40ps rise, 37ps fall
            if (in == 1'b1)
                delay_out[0] <= #0.040 in;
            else
                delay_out[0] <= #0.037 in;
        end else begin
            // I1 path (delayed): 38ps rise, 34ps fall
            if (delay_in[0] == 1'b1)
                delay_out[0] <= #0.038 delay_in[0];
            else
                delay_out[0] <= #0.034 delay_in[0];
        end
    end
    
    // Stage 1: Buffer delay + Mux delay
    // Buffer: 23ps rise, 24ps fall
    always @(delay_out[0]) begin
        if (delay_out[0] == 1'b1)
            delay_in[1] <= #0.023 delay_out[0];
        else
            delay_in[1] <= #0.024 delay_out[0];
    end
    
    // Mux: I0=delay_out[0] (direct), I1=delay_in[1] (delayed), S=select[1]
    always @(delay_out[0] or delay_in[1] or select[1]) begin
        if (select[1] == 1'b0) begin
            // I0 path (direct): 42ps rise, 41ps fall
            if (delay_out[0] == 1'b1)
                delay_out[1] <= #0.042 delay_out[0];
            else
                delay_out[1] <= #0.041 delay_out[0];
        end else begin
            // I1 path (delayed): 38ps rise, 34ps fall
            if (delay_in[1] == 1'b1)
                delay_out[1] <= #0.038 delay_in[1];
            else
                delay_out[1] <= #0.034 delay_in[1];
        end
    end
    
    // Stage 2: Buffer delay + Mux delay
    // Buffer: 23ps rise, 24ps fall
    always @(delay_out[1]) begin
        if (delay_out[1] == 1'b1)
            delay_in[2] <= #0.023 delay_out[1];
        else
            delay_in[2] <= #0.024 delay_out[1];
    end
    
    always @(delay_out[1] or delay_in[2] or select[2]) begin
        if (select[2] == 1'b0) begin
            // I0 path (direct): 42ps rise, 41ps fall
            if (delay_out[1] == 1'b1)
                delay_out[2] <= #0.042 delay_out[1];
            else
                delay_out[2] <= #0.041 delay_out[1];
        end else begin
            // I1 path (delayed): 38ps rise, 34ps fall
            if (delay_in[2] == 1'b1)
                delay_out[2] <= #0.038 delay_in[2];
            else
                delay_out[2] <= #0.034 delay_in[2];
        end
    end
    
    // Stage 3: Buffer delay + Mux delay (последний каскад с другими задержками)
    // Buffer: 23ps rise, 24ps fall
    always @(delay_out[2]) begin
        if (delay_out[2] == 1'b1)
            delay_in[3] <= #0.023 delay_out[2];
        else
            delay_in[3] <= #0.024 delay_out[2];
    end
    
    // Mux: I0=delay_out[2] (direct), I1=delay_in[3] (delayed), S=select[3], Z=out
    always @(delay_out[2] or delay_in[3] or select[3]) begin
        if (select[3] == 1'b0) begin
            // I0 path (direct): 33ps rise, 34ps fall
            if (delay_out[2] == 1'b1)
                out <= #0.033 delay_out[2];
            else
                out <= #0.034 delay_out[2];
        end else begin
            // I1 path (delayed): 29ps rise, 27ps fall
            if (delay_in[3] == 1'b1)
                out <= #0.029 delay_in[3];
            else
                out <= #0.027 delay_in[3];
        end
    end

endmodule