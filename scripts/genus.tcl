
source ../scripts/setup_env.tcl

# =====================================================
# Step 1: Read MMMC (must be before read_hdl/elaborate)
# =====================================================
puts "\n=========================================="
puts "Step 1: Setting up multi-corner MMMC"
puts "=========================================="
read_mmmc ../synth/constraints/mmmc.tcl

# =====================================================
# Step 2: Read physical libraries
# =====================================================
read_physical -lef $design(LEF_FILES)

# =====================================================
# Step 3: Read RTL and Elaborate Design
# =====================================================
puts "\n=========================================="
puts "Step 3: Reading RTL and Elaborating Design"
puts "=========================================="
read_hdl -sv $design(VERILOG_FILES) -define Nmbr_cascades=$design(Nmbr_cascades)

elaborate $design(DESIGN)

check_design

init_design

puts "MMMC setup: view_slow (SSG), view_typ (TT), view_fast (FFG)"

syn_generic
# syn_map

# =====================================================
# Step 4: Save Design Checkpoint + Multi-corner SDF
# =====================================================
puts "\n=========================================="
puts "Step 4: Saving Design Checkpoint"
puts "=========================================="

write_hdl > ../synth/out/$design(DESIGN)_netlist.v
write_sdc -view view_typ > ../synth/out/$design(DESIGN).sdc

# Write SDF per corner
foreach corner $design(CORNERS) {
    set clabel [lindex $corner 0]
    set cview  [lindex $corner 1]
    set sdf_file "../synth/out/${design(DESIGN)}_${clabel}.sdf"
    puts "Writing SDF for $clabel ($cview) -> $sdf_file"
    write_sdf -view $cview > $sdf_file
}

puts "\nSynthesis complete. Run Python analysis:"
puts "  python3 ../parsing/sdf_analysis.py"
if {![info exists ::no_gui]} { gui_show }
