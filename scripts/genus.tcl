
source ../scripts/setup_env.tcl

# =============================================
read_libs $design(LIB_FILES)
read_physical -lef $design(LEF_FILES)
read_qrc $design(QRC_FILE)
# =============================================

# =====================================================
# Step 1: Read RTL and Elaborate Design
# =====================================================
puts "\n=========================================="
puts "Step 1: Reading RTL and Elaborating Design"
puts "=========================================="
# Прочитать RTL
read_hdl -sv $design(VERILOG_FILES) -define Nmbr_cascades=$design(Nmbr_cascades)





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
# Step 2.1: Find Optimal Delay Sequences
# =====================================================
puts "\n=========================================="
puts "Step 2.1: Finding Optimal Delay Sequences"
puts "=========================================="
exec python3 ../scripts/find_delay_sequence.py ../reports/delay_simplified.txt -n 16 --min-step 8 --max-step 30 -o ../reports/delay_sequence.csv | tee ../reports/sequence_analysis.txt
puts "Sequence analysis saved to reports/sequence_analysis.txt"

# =====================================================
# Step 3: Save Design Checkpoint
# =====================================================
puts "\n=========================================="
puts "Step 3: Saving Design Checkpoint"
puts "=========================================="

write_hdl > ../synth/out/$design(DESIGN)_netlist.v
write_sdf > ../synth/out/$design(DESIGN).sdf
write_sdc > ../synth/out/$design(DESIGN).sdc
# gui_show
# quit