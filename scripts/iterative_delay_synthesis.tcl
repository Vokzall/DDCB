# =====================================================
# Iterative Buffer Insertion Script for Delay Lines
# =====================================================

# =====================================================
# Configuration
# =====================================================

# Целевые задержки для каждой линии (в пикосекундах)
set target_delays {2500 5000 7500 10000}

# Допустимое отклонение от целевой задержки (в процентах)
set tolerance 5.0

# Тип буферной ячейки для вставки
set buffer_cell "BUFV1_140P9T30R"

# Максимальное количество итераций для одной линии
set max_iterations 500

# =====================================================
# Helper Functions
# =====================================================

# Функция для получения задержки пути
proc get_path_delay {from_port to_port} {
    # Используем report_timing и парсим результат для получения задержки
    # Убрал неподдерживаемый флаг -quiet и явно запросил текстовый вывод
    set timing_report [report_timing -from $from_port -to $to_port -max_paths 1 -output_format text]

    set lines [split $timing_report "\n"]
    foreach line $lines {
        set line_lower [string tolower $line]
        if {[string first "data arrival time" $line_lower] >= 0 || [string match "*data arrival time*" $line_lower]} {
            if {[regexp {([0-9]+\.?[0-9]*)} $line match delay]} {
                return $delay
            }
        }
        # Some report_timing outputs contain a line with "path delay" or just a numeric value
        if {[regexp {path delay.*([0-9]+\.?[0-9]*)} $line_lower match delay2]} {
            return $delay2
        }
        if {[regexp {^\s*([0-9]+\.?[0-9]*)\s*ps} $line_lower match delay3]} {
            return $delay3
        }
    }

    return 0
}

# Функция для получения всех пинов на пути
proc get_path_pins {from_port to_port} {
    # Собираем упрощённый список пинов вдоль пути между портами
    set pins_list {}

    # Начнём с порта-источника
    lappend pins_list $from_port

    # Попробуем получить объекты, которые находятся во фан-ауте пути
    set fanout_result [catch {set fanout_objs [get_fanout -from $from_port -to $to_port -quiet]} _]
    if {$fanout_result == 0} {
        foreach obj $fanout_objs {
            if {[catch {set obj_type [get_object_type $obj]} err]} {
                continue
            }
            if {$obj_type == "pin"} {
                lappend pins_list $obj
            } else {
                # Попробуем получить пины объекта (если это инстанс)
                if {[catch {set pcol [get_pins $obj -quiet]} _] == 0} {
                    foreach p $pcol {
                        lappend pins_list $p
                    }
                }
            }
        }
    }

    # Добавим порт-приёмник в конец списка
    lappend pins_list $to_port

    return $pins_list
}

# Функция для вставки буфера на первый доступный пин после входного порта
proc insert_buffer_on_path {line_index buffer_cell iteration} {
    set from_port [get_ports delay_lines[$line_index]]
    set to_port [get_ports out]
    
    # Получить пины на пути
    set path_pins [get_path_pins $from_port $to_port]
    
    if {[llength $path_pins] == 0} {
        puts "ERROR: No pins found on path for delay_lines\[$line_index\]"
        return 0
    }
    
    # Найти первый внутренний пин после входного порта
    set target_pin ""
    foreach pin $path_pins {
        set pin_obj [get_pins $pin -quiet]
        if {[sizeof_collection $pin_obj] > 0} {
            set pin_dir [get_db $pin_obj .direction]
            # Ищем входной пин внутренней ячейки
            if {$pin_dir == "in"} {
                set target_pin $pin
                break
            }
        }
    }
    
    if {$target_pin == ""} {
        puts "WARNING: Could not find suitable pin for buffer insertion on line $line_index"
        return 0
    }
    
    # Имя нового буфера
    set buf_name "delay_buf_${line_index}_${iteration}"
    
    # Вставить буфер
    puts "  Inserting buffer: $buf_name at pin $target_pin"
    
    if {[catch {
        insert_buffer -name $buf_name -buffer $buffer_cell -pin $target_pin
    } err]} {
        puts "WARNING: Failed to insert buffer: $err"
        return 0
    }
    
    return 1
}

# Функция для проверки достижения цели
proc check_target_reached {current_delay target_delay tolerance} {
    set lower_bound [expr {$target_delay * (1.0 - $tolerance / 100.0)}]
    set upper_bound [expr {$target_delay * (1.0 + $tolerance / 100.0)}]
    
    if {$current_delay >= $lower_bound && $current_delay <= $upper_bound} {
        return 1
    } else {
        return 0
    }
}

# =====================================================
# Main Buffer Insertion Loop
# =====================================================

proc insert_buffers_for_delay_lines {target_delays buffer_cell tolerance max_iterations} {
    
    puts "\n=========================================="
    puts "Starting Iterative Buffer Insertion"
    puts "=========================================="
    puts "Buffer cell: $buffer_cell"
    puts "Tolerance: ${tolerance}%"
    puts "Max iterations per line: $max_iterations"
    puts "==========================================\n"
    
    set num_lines [llength $target_delays]
    set all_success 1
    
    # Обработать каждую линию задержки
    for {set i 0} {$i < $num_lines} {incr i} {
        set target_delay [lindex $target_delays $i]
        set from_port [get_ports delay_lines[$i]]
        set to_port [get_ports out]
        
        puts "\n=========================================="
        puts "Processing delay_lines\[$i\]"
        puts "Target delay: ${target_delay}ps"
        puts "==========================================\n"
        
        set iteration 0
        set target_reached 0
        
        while {$iteration < $max_iterations} {
            # Получить текущую задержку
            set current_delay [get_path_delay $from_port $to_port]
            
            # Проверить достижение цели
            if {[check_target_reached $current_delay $target_delay $tolerance]} {
                puts "SUCCESS: Target delay reached!"
                puts "  Current delay: ${current_delay}ps"
                puts "  Target delay:  ${target_delay}ps"
                puts "  Total buffers inserted: $iteration\n"
                set target_reached 1
                break
            }
            
            # Если текущая задержка больше максимально допустимой - остановиться
            set max_allowed [expr {$target_delay * (1.0 + $tolerance / 100.0)}]
            if {$current_delay > $max_allowed} {
                puts "WARNING: Delay exceeded maximum allowed value!"
                puts "  Current delay: ${current_delay}ps"
                puts "  Max allowed:   ${max_allowed}ps"
                puts "  Total buffers inserted: $iteration\n"
                set all_success 0
                break
            }
            
            # Вывести прогресс каждые 10 итераций
            if {$iteration % 10 == 0} {
                set progress [expr {($current_delay * 100.0) / $target_delay}]
                puts "  Iteration $iteration: ${current_delay}ps (${progress}% of target)"
            }
            
            # Вставить буфер
            set success [insert_buffer_on_path $i $buffer_cell $iteration]
            
            if {!$success} {
                puts "ERROR: Failed to insert buffer on iteration $iteration"
                set all_success 0
                break
            }
            
            # Инкрементальная оптимизация после каждой вставки
            # Можно закомментировать для ускорения, но может привести к неточностям
            if {$iteration % 5 == 0 && $iteration > 0} {
                syn_opt -incremental
            }
            
            incr iteration
        }
        
        if {!$target_reached} {
            if {$iteration >= $max_iterations} {
                puts "ERROR: Maximum iterations reached without achieving target delay"
                set current_delay [get_path_delay $from_port $to_port]
                puts "  Final delay: ${current_delay}ps"
                puts "  Target delay: ${target_delay}ps"
                puts "  Deficit: [expr {$target_delay - $current_delay}]ps\n"
                set all_success 0
            }
        }
    }
    
    return $all_success
}

# =====================================================
# Post-processing and Reporting
# =====================================================

proc generate_final_report {target_delays} {
    puts "\n=========================================="
    puts "Final Timing Report"
    puts "=========================================="
    
    set num_lines [llength $target_delays]
    
    for {set i 0} {$i < $num_lines} {incr i} {
        set target_delay [lindex $target_delays $i]
        set from_port [get_ports delay_lines[$i]]
        set to_port [get_ports out]
        set current_delay [get_path_delay $from_port $to_port]
        
        set error [expr {abs($current_delay - $target_delay)}]
        set error_pct [expr {($error * 100.0) / $target_delay}]
        
        puts "\ndelay_lines\[$i\]:"
        puts "  Target delay:  ${target_delay}ps"
        puts "  Actual delay:  ${current_delay}ps"
        puts "  Error:         ${error}ps (${error_pct}%)"
        
        if {$error_pct > 5.0} {
            puts "  Status:        FAIL"
        } else {
            puts "  Status:        PASS"
        }
    }
    
    puts "\n=========================================="
    puts "Detailed Timing Paths"
    puts "=========================================="
    
    report_timing \
        -from [get_ports delay_lines*] \
        -to [get_ports out] \
        -max_paths $num_lines \
        -path_type full
    
    puts "\n=========================================="
    puts "Area Report"
    puts "=========================================="
    
    report_area
    
    puts "\n=========================================="
    puts "Buffer Count by Type"
    puts "=========================================="
    
    report_gates -power
}

# =====================================================
# Main Execution
# =====================================================

puts "\n=========================================="
puts "Delay Line Buffer Insertion Script"
puts "=========================================="

# Проверить что дизайн загружен
set current_design [get_db current_design]
if {$current_design == ""} {
    puts "ERROR: No design loaded. Please elaborate design first."
    return
}

# Проверить что SDC загружен
if {[sizeof_collection [get_ports delay_lines*]] == 0} {
    puts "ERROR: delay_lines ports not found. Please check design."
    return
}

# Проверить доступность буферной ячейки
if {[sizeof_collection [get_lib_cells */$buffer_cell]] == 0} {
    puts "ERROR: Buffer cell $buffer_cell not found in loaded libraries."
    puts "Available buffer cells:"
    foreach cell [get_lib_cells */BUF*] {
        puts "  [get_db $cell .name]"
    }
    return
}

puts "Configuration:"
puts "  Buffer cell: $buffer_cell"
puts "  Target delays: $target_delays ps"
puts "  Tolerance: ${tolerance}%"
puts ""

# Выполнить начальный синтез, если еще не выполнен
set synth_check [catch {get_insts} result]

if {$synth_check != 0 || [sizeof_collection $result] == 0} {
    puts "Running initial synthesis..."
    syn_generic
    syn_map
} else {
    puts "Design already has instances, skipping syn_generic and syn_map"
}

# Вывести начальное состояние
puts "\n=========================================="
puts "Initial Timing State"
puts "=========================================="

for {set i 0} {$i < [llength $target_delays]} {incr i} {
    set target [lindex $target_delays $i]
    set current [get_path_delay [get_ports delay_lines[$i]] [get_ports out]]
    puts "delay_lines\[$i\]: ${current}ps (target: ${target}ps)"
}

# Запустить итеративную вставку буферов
set success [insert_buffers_for_delay_lines $target_delays $buffer_cell $tolerance $max_iterations]

# Финальная оптимизация
puts "\n=========================================="
puts "Running Final Optimization"
puts "=========================================="
syn_opt -incremental

# Сгенерировать финальный отчет
generate_final_report $target_delays

# Проверить нарушения timing
set late_report [report_timing -nworst 1 -max_slack 0 -output_format text]
if {[string trim $late_report] != ""} {
    puts "\n=========================================="
    puts "WARNING: Timing Violations Found"
    puts "=========================================="
    report_timing -nworst 10 -max_slack 0
}

# Сохранить результаты
puts "\n=========================================="
puts "Saving Results"
puts "=========================================="

write_hdl > ../reports/muxed_delays_synth.v
write_sdc > ../reports/muxed_delays_synth.sdc
write_sdf -precision 3 > ../reports/muxed_delays.sdf

if {$success} {
    puts "\nSUCCESS: All delay targets achieved!"
} else {
    puts "\nWARNING: Some delay targets were not achieved."
    puts "Consider:"
    puts "  1. Increasing max_iterations"
    puts "  2. Adjusting tolerance"
    puts "  3. Using different buffer cell"
    puts "  4. Checking if target delays are realistic for the technology"
}

puts "\n=========================================="
puts "Buffer Insertion Complete"
puts "=========================================="