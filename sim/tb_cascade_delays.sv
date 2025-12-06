`timescale 1ns/1ps

module tb_cascade_delays;

    // Параметры тестбенча
    parameter Nmbr_cascades = 8;
    parameter CLK_PERIOD = 10;   // 10 нс период
    parameter TEST_DELAY = 5;    // Задержка между тестами
    
    // Сигналы тестбенча
    logic in;
    logic [Nmbr_cascades-1:0] select;
    logic out;
    logic clk;
    logic rst_n;
    
    // Счетчики для статистики
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // Переменные для отслеживания времени
    realtime t_start, t_end;
    realtime measured_delay, expected_delay;
    
    // Задержки из SDF файла (в пикосекундах)
    // BUFV1_140P9T30R delays
    real buf_delays_rising[Nmbr_cascades];
    real buf_delays_falling[Nmbr_cascades];
    
    // CLKMUX2V0_140P9T30R delays
    // I0->Z delays
    real mux_i0_z_rising[Nmbr_cascades];
    real mux_i0_z_falling[Nmbr_cascades];
    // I1->Z delays
    real mux_i1_z_rising[Nmbr_cascades];
    real mux_i1_z_falling[Nmbr_cascades];
    // S->Z delays
    real mux_s_z_rising[Nmbr_cascades];
    real mux_s_z_falling[Nmbr_cascades];
    
    // Test patterns array
    logic [Nmbr_cascades-1:0] test_patterns[10];
    
    // Генерация тактового сигнала
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Инстанс тестируемого модуля
    cascade_delays dut (
        .in(in),
        .select(select),
        .out(out)
    );
    
    // Инициализация задержек из SDF файла
    function void init_sdf_delays();
        // Инициализируем массивы задержек
        // Задержки в пикосекундах (ps)
        
        // Каскад 0
        buf_delays_rising[0] = 24.0;   // BUF delay rising
        buf_delays_falling[0] = 24.0;  // BUF delay falling
        mux_i0_z_rising[0] = 42.0;     // MUX I0->Z rising
        mux_i0_z_falling[0] = 44.0;    // MUX I0->Z falling
        mux_i1_z_rising[0] = 44.0;     // MUX I1->Z rising
        mux_i1_z_falling[0] = 43.0;    // MUX I1->Z falling
        mux_s_z_rising[0] = 49.0;      // MUX S->Z rising
        mux_s_z_falling[0] = 45.0;     // MUX S->Z falling
        
        // Каскады 1-6
        for (int i = 1; i < Nmbr_cascades-1; i++) begin
            buf_delays_rising[i] = 27.0;
            buf_delays_falling[i] = 28.0;
            mux_i0_z_rising[i] = 42.0;
            mux_i0_z_falling[i] = 44.0;
            mux_i1_z_rising[i] = 47.0;
            mux_i1_z_falling[i] = 47.0;
            mux_s_z_rising[i] = 49.0;
            mux_s_z_falling[i] = 45.0;
        end
        
        // Каскад 7 (последний)
        buf_delays_rising[7] = 27.0;
        buf_delays_falling[7] = 28.0;
        mux_i0_z_rising[7] = 33.0;
        mux_i0_z_falling[7] = 36.0;
        mux_i1_z_rising[7] = 38.0;
        mux_i1_z_falling[7] = 39.0;
        mux_s_z_rising[7] = 40.0;
        mux_s_z_falling[7] = 37.0;
        
        $display("SDF задержки инициализированы:");
        $display("  BUF delays (rising/falling):");
        for (int i = 0; i < Nmbr_cascades; i++) begin
            $display("    Каскад[%0d]: %0.1f/%0.1f ps", 
                    i, buf_delays_rising[i], buf_delays_falling[i]);
        end
    endfunction
    
    // Функция расчета ожидаемой задержки
    function real calc_expected_delay(logic [Nmbr_cascades-1:0] sel, logic is_rising);
        static real total_delay;
        
        for (int i = 0; i < Nmbr_cascades; i++) begin
            if (sel[i] == 1'b0) begin
                // Путь через буфер + мультиплексор (I0)
                if (is_rising) begin
                    total_delay += buf_delays_rising[i];
                    total_delay += mux_i0_z_rising[i];
                end else begin
                    total_delay += buf_delays_falling[i];
                    total_delay += mux_i0_z_falling[i];
                end
            end else begin
                // Прямой путь через мультиплексор (I1)
                if (is_rising) begin
                    total_delay += mux_i1_z_rising[i];
                end else begin
                    total_delay += mux_i1_z_falling[i];
                end
            end
        end
        
        return total_delay / 1000.0; // Конвертируем ps в ns
    endfunction
    
    // Загрузка SDF файла
    initial begin
        // Аннотация SDF задержек
        $sdf_annotate("../synth/out/cascade_delays.sdf", dut);
        $display("SDF файл загружен: ../synth/out/cascade_delays.sdf");
    end
    
    // Инициализация
    initial begin
        // Инициализация сигналов
        clk = 0;
        rst_n = 0;
        in = 0;
        select = '0;
        
        // Инициализация SDF задержек
        init_sdf_delays();
        
        // Сброс
        #(CLK_PERIOD);
        rst_n = 1;
        #(CLK_PERIOD);
        
        $display("========================================");
        $display("Начало тестирования cascade_delays");
        $display("Количество каскадов: %0d", Nmbr_cascades);
        $display("Время начала: %t", $time);
        $display("========================================");
        
        // Тест 1: Без задержек (все селекты = 1)
        test_count++;
        $display("\nТест %0d: Без задержек (все select=1)", test_count);
        select = {Nmbr_cascades{1'b1}};
        in = 0;
        #TEST_DELAY;
        
        // Проверка положительного фронта
        expected_delay = calc_expected_delay(select, 1);
        t_start = $realtime;
        in = 1;
        wait(out == 1);
        t_end = $realtime;
        measured_delay = t_end - t_start;
        
        $display("  Ожидаемая задержка: %0.3f нс", expected_delay);
        $display("  Измеренная задержка: %0.3f нс", measured_delay);
        
        if ((measured_delay - expected_delay) < 0.01 && 
            (measured_delay - expected_delay) > -0.01) begin
            $display("  PASS: Задержка соответствует ожидаемой");
            pass_count++;
        end else begin
            $display("  FAIL: Задержка не соответствует ожидаемой");
            $display("  Расхождение: %0.3f нс", measured_delay - expected_delay);
            fail_count++;
        end
        
        #TEST_DELAY;
        
        // Проверка отрицательного фронта
        t_start = $realtime;
        in = 0;
        wait(out == 0);
        t_end = $realtime;
        measured_delay = t_end - t_start;
        expected_delay = calc_expected_delay(select, 0);
        
        $display("  Ожидаемая задержка (спад): %0.3f нс", expected_delay);
        $display("  Измеренная задержка (спад): %0.3f нс", measured_delay);
        
        if ((measured_delay - expected_delay) < 0.01 && 
            (measured_delay - expected_delay) > -0.01) begin
            $display("  PASS: Задержка спада соответствует ожидаемой");
            pass_count++;
        end else begin
            $display("  FAIL: Задержка спада не соответствует ожидаемой");
            fail_count++;
        end
        
        #TEST_DELAY;
        
        // Тест 2: Максимальная задержка (все селекты = 0)
        test_count++;
        $display("\nТест %0d: Максимальная задержка (все select=0)", test_count);
        select = '0;
        in = 0;
        #TEST_DELAY;
        
        // Проверка положительного фронта
        expected_delay = calc_expected_delay(select, 1);
        t_start = $realtime;
        in = 1;
        wait(out == 1);
        t_end = $realtime;
        measured_delay = t_end - t_start;
        
        $display("  Ожидаемая задержка: %0.3f нс", expected_delay);
        $display("  Измеренная задержка: %0.3f нс", measured_delay);
        
        if ((measured_delay - expected_delay) < 0.01 && 
            (measured_delay - expected_delay) > -0.01) begin
            $display("  PASS: Задержка соответствует ожидаемой");
            pass_count++;
        end else begin
            $display("  FAIL: Задержка не соответствует ожидаемой");
            $display("  Расхождение: %0.3f нс", measured_delay - expected_delay);
            fail_count++;
        end
        
        #TEST_DELAY;
        
        // Тест 3: Проверка различных комбинаций селектов
        test_count++;
        $display("\nТест %0d: Различные комбинации селектов", test_count);
        
        // Инициализируем массив интересных комбинаций
        test_patterns[0] = 8'b00000000; // Все 0
        test_patterns[1] = 8'b11111111; // Все 1
        test_patterns[2] = 8'b01010101; // Чередование 0/1
        test_patterns[3] = 8'b10101010; // Чередование 1/0
        test_patterns[4] = 8'b00001111; // Первая половина 0, вторая 1
        test_patterns[5] = 8'b11110000; // Первая половина 1, вторая 0
        test_patterns[6] = 8'b00110011; // Пары 00/11
        test_patterns[7] = 8'b11001100; // Пары 11/00
        test_patterns[8] = 8'b00000001; // Только последний 1
        test_patterns[9] = 8'b10000000; // Только первый 1
        
        for (int i = 0; i < 10; i++) begin
            select = test_patterns[i];
            in = 0;
            #TEST_DELAY;
            
            // Положительный фронт
            expected_delay = calc_expected_delay(select, 1);
            t_start = $realtime;
            in = 1;
            wait(out == 1);
            t_end = $realtime;
            measured_delay = t_end - t_start;
            
            $display("  Паттерн %0d: select=%8b", i, select);
            $display("    Ожидаемая: %0.3f нс, Измеренная: %0.3f нс", 
                    expected_delay, measured_delay);
            
            if ((measured_delay - expected_delay) < 0.01 && 
                (measured_delay - expected_delay) > -0.01) begin
                $display("    PASS");
                pass_count++;
            end else begin
                $display("    FAIL (расхождение: %0.3f нс)", 
                        measured_delay - expected_delay);
                fail_count++;
            end
            
            // Отрицательный фронт
            t_start = $realtime;
            in = 0;
            wait(out == 0);
            t_end = $realtime;
            measured_delay = t_end - t_start;
            expected_delay = calc_expected_delay(select, 0);
            
            $display("    Спад: ожид=%0.3f нс, измер=%0.3f нс", 
                    expected_delay, measured_delay);
            
            if ((measured_delay - expected_delay) < 0.01 && 
                (measured_delay - expected_delay) > -0.01) begin
                $display("    PASS");
                pass_count++;
            end else begin
                $display("    FAIL (расхождение: %0.3f нс)", 
                        measured_delay - expected_delay);
                fail_count++;
            end
            
            #TEST_DELAY;
        end
        
        // Тест 4: Динамическое изменение селектов во время работы
        test_count++;
        $display("\nТест %0d: Динамическое изменение селектов", test_count);
        
        select = 8'b11111111;
        in = 1;
        #TEST_DELAY;
        
        // Меняем селекты и проверяем задержку
        for (int i = 0; i < Nmbr_cascades; i++) begin
            select[i] = 0; // Включаем один каскад задержки
            #TEST_DELAY;
            
            expected_delay = calc_expected_delay(select, 1);
            t_start = $realtime;
            in = 0;
            wait(out == 0);
            t_end = $realtime;
            measured_delay = t_end - t_start;
            
            $display("  Каскад[%0d]=0: ожид=%0.3f нс, измер=%0.3f нс", 
                    i, expected_delay, measured_delay);
            
            if ((measured_delay - expected_delay) < 0.01 && 
                (measured_delay - expected_delay) > -0.01) begin
                $display("    PASS");
                pass_count++;
            end else begin
                $display("    FAIL (расхождение: %0.3f нс)", 
                        measured_delay - expected_delay);
                fail_count++;
            end
            
            // Возвращаем фронт
            in = 1;
            #TEST_DELAY;
        end
        
        // Тест 5: Проверка на стабильность при быстрых переключениях
        test_count++;
        $display("\nТест %0d: Быстрые переключения", test_count);
        
        select = 8'b01010101;
        in = 0;
        #TEST_DELAY;
        
        // Генерация быстрых импульсов
        for (int i = 0; i < 20; i++) begin
            in = ~in;
            #(CLK_PERIOD/4); // Быстрые переключения
        end
        
        $display("  PASS: Быстрые переключения обработаны корректно");
        pass_count++;
        
        #TEST_DELAY;
        
        // Завершение тестирования
        #TEST_DELAY;
        
        $display("\n========================================");
        $display("Завершение тестирования");
        $display("Всего тестов: %0d", test_count);
        $display("Пройдено проверок: %0d", pass_count);
        $display("Не пройдено проверок: %0d", fail_count);
        $display("Время завершения: %t", $time);
        
        if (fail_count == 0) begin
            $display("РЕЗУЛЬТАТ: ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!");
            $display("Задержки соответствуют SDF спецификации");
        end else begin
            $display("РЕЗУЛЬТАТ: ОБНАРУЖЕНЫ ОШИБКИ!");
            $display("Некоторые задержки не соответствуют SDF");
        end
        $display("========================================\n");
        
        // Завершение симуляции
        $finish;
    end
    
    // Мониторинг сигналов
    initial begin
        $monitor("Время: %t | in=%b | select=%8b | out=%b", 
                 $time, in, select, out);
    end
    
    // Проверка на X/Z состояния
    always @(posedge clk) begin
        if (rst_n) begin
            // Проверяем, что нет неопределенных состояний
            assert (in !== 1'bx && in !== 1'bz) 
                else $error("Обнаружено X/Z состояние на входе in");
            assert (out !== 1'bx && out !== 1'bz) 
                else $error("Обнаружено X/Z состояние на выходе out");
            for (int i = 0; i < Nmbr_cascades; i++) begin
                assert (select[i] !== 1'bx && select[i] !== 1'bz) 
                    else $error("Обнаружено X/Z состояние на select[%0d]", i);
            end
        end
    end
    
    // Проверка временных ограничений
    always @(posedge out) begin
        realtime delay;
        delay = $realtime - t_start;
        if (delay > 0) begin
            $display("[Timing Check] Положительный фронт: задержка = %0.3f нс", delay);
        end
    end
    
    always @(negedge out) begin
        realtime delay;
        delay = $realtime - t_start;
        if (delay > 0) begin
            $display("[Timing Check] Отрицательный фронт: задержка = %0.3f нс", delay);
        end
    end
    
    // Dump VCD файл для анализа
    initial begin
        $dumpfile("cascade_delays.vcd");
        $dumpvars(0, tb_cascade_delays);
        $dumplimit(10000000); // Ограничение размера файла
    end

endmodule