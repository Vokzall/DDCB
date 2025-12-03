
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

# gui_show