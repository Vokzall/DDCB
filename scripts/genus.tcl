
source ../scripts/setup_env.tcl

# =============================================
read_libs $design(LIB_FILES)
# read_lefs $design(LEF_FILES)
# =============================================

# =====================================================
# Step 1: Read RTL and Elaborate Design
# =====================================================
puts "\n=========================================="
puts "Step 1: Reading RTL and Elaborating Design"
puts "=========================================="
# Прочитать RTL
read_hdl -sv $design(VERILOG_FILES)

# Elaborate
elaborate $design(DESIGN)

check_design

# Прочитать SDC
read_sdc $design(SDC_FILE)

syn_generic
# syn_map

# =====================================================
# Step 2: Generate Delay Summary Table
# =====================================================
source ../scripts/generate_table_delays.tcl

# =====================================================
# Step 3: Save Design Checkpoint
# =====================================================
puts "\n=========================================="
puts "Step 3: Saving Design Checkpoint"
puts "=========================================="

write_hdl > ../synth/out/$design(DESIGN)_netlist.v
write_sdf > ../synth/out/$design(DESIGN).sdf
write_sdc > ../synth/out/$design(DESIGN).sdc
gui_show