# Создаем проект для симуляции
create_project -force sim_project ./sim_project -part xc7z020clg400-1
set_property target_language Verilog [current_project]

# Добавляем исходные файлы (исключая *asic*)
add_files -fileset sources_1 \
    [list ../src/IDELAYE3.v \
     ../src/ODELAYE3.v]

# Добавляем тестовые окружения
add_files -fileset sim_1 \
    [list ../sim/tb_IDELAYE3.sv \
     ../sim/tb_ODELAYE3.sv]

# Обновляем компиляцию файлов
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Устанавливаем политику симуляции
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]

# Устанавливаем первый тестбенч как верхний уровень для симуляции
set_property top tb_IDELAYE3 [get_filesets sim_1]

# Компилируем симуляцию
compile_simulation -simset sim_1

# Запускаем симуляцию
launch_simulation -simset sim_1

# Создаем разделители и добавляем ключевые сигналы в waveform
add_wave_divider "Testbench Signals"
add_wave /tb_IDELAYE3/clk
add_wave /tb_IDELAYE3/rst
add_wave /tb_IDELAYE3/start

add_wave_divider "IDELAYE3 Signals"
add_wave /tb_IDELAYE3/dut/*

add_wave_divider "Status Signals"
add_wave /tb_IDELAYE3/done
add_wave /tb_IDELAYE3/error_count

# Устанавливаем формат отображения для некоторых сигналов (опционально)
set_property display_format analog [find wave /tb_IDELAYE3/dut/delay_value]
set_property display_format binary [find wave /tb_IDELAYE3/dut/control_bits]

# Запускаем симуляцию на установленное время
run 100us

# Сохраняем конфигурацию waveform (опционально)
save_wave_config ./waveform_config.wcfg