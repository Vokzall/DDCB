# =====================================================
# Complete Synthesis Flow with Iterative Buffer Insertion
# Running from: workdir/
# =====================================================

# =====================================================
# Step 1: Setup
# =====================================================

puts "=========================================="
puts "Step 1: Loading design and libraries"
puts "=========================================="

# Загрузить библиотеки
set_db init_lib_search_path ../DDK
set_db library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib

set DESIGN muxed_delays

puts "Library loaded: scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib"

# Прочитать RTL
read_hdl -sv ../src/muxed_delays.sv

# Elaborate
elaborate muxed_delays

# Прочитать SDC
read_sdc ../synth/muxed_delays.sdc

puts "Design elaborated successfully"

# =====================================================
# Step 2: Initial Synthesis
# =====================================================

puts "\n=========================================="
puts "Step 2: Running initial synthesis"
puts "=========================================="

# Начальный синтез
syn_generic
syn_map

puts "Initial synthesis completed"

# =====================================================
# Step 3: Configure Buffer Insertion
# =====================================================

puts "\n=========================================="
puts "Step 3: Configuring buffer insertion"
puts "=========================================="

# Настроить параметры вставки буферов
add_assign_buffer_options \
    -buffer_or_inverter BUFV1_140P9T30R \
    -allow_unloaded_buffers

# Разрешить вставку буферов
set_db design:muxed_delays .remove_assigns true
# set_db design:muxed_delays .buffer_and_inverter_to_fix_drc true

puts "Buffer insertion configured"

# =====================================================
# Step 4: Load and Run Iterative Buffer Insertion Script
# =====================================================

puts "\n=========================================="
puts "Step 4: Running iterative buffer insertion"
puts "=========================================="

# Source the iterative insertion script
source ../scripts/iterative_delay_synthesis.tcl

# Скрипт выполнится автоматически после source

puts "\n=========================================="
puts "Synthesis Flow Complete!"
puts "=========================================="
puts "\nGenerated files:"
puts "  - muxed_delays_synth.v    (Synthesized netlist)"
puts "  - muxed_delays_synth.sdc  (Timing constraints)"
puts "  - muxed_delays.sdf        (Delay annotation)"
puts "=========================================="