`timescale 1ns / 1ps

module const_delay (
    input  wire I,
    output wire O
);
    
    // Внутренние сигналы для цепочки задержек
    wire delay_buf1, delay_buf2, delay_buf3, delay_buf4;
    
    // Задержки из SDF файла (конвертировано из пс в нс)
    // DELAY_STAGES[0].u_delay_inst
    assign #(0.133, 0.138) delay_buf1 = I;  // rise: 0.133ns, fall: 0.138ns
    
    // DELAY_STAGES[1].u_delay_inst
    assign #(0.135, 0.143) delay_buf2 = delay_buf1;  // rise: 0.135ns, fall: 0.143ns
    
    // DELAY_STAGES[2].u_delay_inst
    assign #(0.135, 0.143) delay_buf3 = delay_buf2;  // rise: 0.135ns, fall: 0.143ns
    
    // DELAY_STAGES[3].u_delay_inst
    assign #(0.135, 0.143) delay_buf4 = delay_buf3;  // rise: 0.135ns, fall: 0.143ns
    
    // DELAY_STAGES[4].u_delay_inst
    assign #(0.133, 0.141) O = delay_buf4;  // rise: 0.133ns, fall: 0.141ns

endmodule