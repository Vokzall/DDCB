
# =====================================================
# Genus synthesis script for IDELAYE3 / ODELAYE3 wrappers
# Expects: setup_env_file variable set before sourcing
# =====================================================

source ../scripts/${setup_env_file}

# =============================================
# Read libraries, LEF, QRC
# =============================================
read_libs $design(LIB_FILES)
read_physical -lef $design(LEF_FILES)
read_qrc $design(QRC_FILE)

# =====================================================
# Step 1: Read pre-synthesized cascade_delays netlist
# =====================================================
puts "\n=========================================="
puts "Step 1: Reading cascade_delays netlist"
puts "=========================================="
read_hdl $design(NETLIST_FILES)

# =====================================================
# Step 2: Read wrapper RTL and elaborate
# =====================================================
puts "\n=========================================="
puts "Step 2: Reading wrapper RTL and elaborating"
puts "=========================================="
read_hdl -sv $design(VERILOG_FILES) -define Nmbr_cascades=$design(Nmbr_cascades)

elaborate $design(DESIGN)
check_design

# =====================================================
# Step 3: Read SDC and synthesize
# =====================================================
puts "\n=========================================="
puts "Step 3: Constraints and synthesis"
puts "=========================================="
read_sdc $design(SDC_FILE)

syn_generic
# syn_map

# =====================================================
# Step 4: Reports
# =====================================================
puts "\n=========================================="
puts "Step 4: Reports"
puts "=========================================="
report_timing > $design(REPORT_DIR)/$design(DESIGN)_timing.rpt
report_area   > $design(REPORT_DIR)/$design(DESIGN)_area.rpt

# =====================================================
# Step 5: Save outputs
# =====================================================
puts "\n=========================================="
puts "Step 5: Saving design"
puts "=========================================="
write_hdl > ../synth/out/$design(DESIGN)_netlist.v
write_sdf > ../synth/out/$design(DESIGN).sdf
write_sdc > ../synth/out/$design(DESIGN).sdc

puts "\nDone: $design(DESIGN) synthesis complete."
if {![info exists ::no_gui]} { gui_show }
