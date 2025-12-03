# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Detailed timing analysis for programmable delay line
# =====================================================

puts "\n=========================================="
puts "Generating Detailed Delay Analysis"
puts "=========================================="

# Create reports directory if it doesn't exist
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

# Auto-detect number of cascades by counting select pins
set select_pins [get_db ports select*]
set num_cascades [llength $select_pins]

if {$num_cascades == 0} {
    puts "ERROR: Could not detect select pins. Design might not be elaborated properly."
    return
}

puts "Auto-detected $num_cascades cascade stages from select\[$num_cascades-1:0\] pins"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

# Open files for writing
set tbl_fh [open $table_file "w"]
set det_fh [open $detailed_file "w"]

# Write table headers
puts $tbl_fh "=================================================================================="
puts $tbl_fh "           PROGRAMMABLE DELAY LINE - DETAILED TIMING ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:      $design(DESIGN)"
puts $tbl_fh "Technology:  $design(TECHNOLOGY)"
puts $tbl_fh "Stages:      $num_cascades"
puts $tbl_fh "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""

# Function to convert binary to select pattern
proc binary_to_select {value width} {
    set pattern ""
    for {set i [expr $width - 1]} {$i >= 0} {incr i -1} {
        set bit [expr ($value >> $i) & 1]
        append pattern $bit
    }
    return $pattern
}

# Function to extract detailed path information from timing report
proc extract_path_details {report_text} {
    set total_delay 0
    set buffer_count 0
    set buffer_delay 0
    
    set lines [split $report_text "\n"]
    
    # Find "Data Path:-" line for total delay
    foreach line $lines {
        if {[regexp {Data Path:-\s+(\d+)} $line match delay]} {
            set total_delay $delay
            break
        }
    }
    
    # Parse the timing path table to extract buffer information
    # Format: cell_name/Z (P) I->Z R/F BUFV1_140P9T30R fanout load trans delay arrival
    foreach line $lines {
        # Look for BUFV1 buffer cells
        if {[regexp {BUFV1_140P9T30R\s+\d+\s+[\d.]+\s+(\d+)\s+(\d+)\s+\d+} $line match trans delay]} {
            incr buffer_count
            set buffer_delay [expr {$buffer_delay + $delay}]
        }
    }
    
    return [list $total_delay $buffer_count $buffer_delay]
}

# Calculate total number of configurations
set total_configs [expr {1 << $num_cascades}]

puts "Analyzing $total_configs different select configurations..."
puts "Extracting buffer/mux counts and delays for each path...\n"

# Get input and output ports
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find input/output ports"
    close $tbl_fh
    close $det_fh
    return
}

# Data structures to store results
array set rise_data {}
array set fall_data {}

# Analyze each configuration
for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    
    puts "Processing configuration $config: select = $select_pattern"
    
    # Analyze both transitions
    foreach transition {rise fall} {
        if {$transition == "rise"} {
            set from_opt "-from_rise"
            set to_opt "-to_rise"
        } else {
            set from_opt "-from_fall"
            set to_opt "-to_fall"
        }
        
        # Generate timing report
        set report_file "${design(REPORT_DIR)}/temp_timing_${config}_${transition}.rpt"
        
        report_timing \
            $from_opt $in_port \
            $to_opt $out_port \
            -unconstrained \
            -path_type full \
            -max_paths 1 \
            > $report_file
        
        # Read the report
        set temp_fh [open $report_file "r"]
        set report_content [read $temp_fh]
        close $temp_fh
        
        # Save detailed report
        puts $det_fh "\n=========================================="
        puts $det_fh "Config: $config | Select: $select_pattern | Transition: $transition"
        puts $det_fh "=========================================="
        puts $det_fh $report_content
        
        # Extract path details
        lassign [extract_path_details $report_content] total_delay buf_cnt buf_dly
        
        # Store data
        if {$transition == "rise"} {
            set rise_data($config) [list $total_delay $buf_cnt $buf_dly]
        } else {
            set fall_data($config) [list $total_delay $buf_cnt $buf_dly]
        }
        
        # Remove temporary file
        file delete $report_file
    }
}

# Write detailed results table
puts $tbl_fh "RISE TRANSITION ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "| Cfg | Select | Total | Buffer       | Logic/Wire   | Buffer    | Effective |"
puts $tbl_fh "|     | Pattern| Delay | Count | Delay| Delay        | per Stage | Stages    |"
puts $tbl_fh "|     |        | (ps)  |       | (ps) | (ps)         | (ps)      | Active    |"
puts $tbl_fh "=================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    lassign $rise_data($config) total buf_cnt buf_dly
    
    set logic_delay [expr {$total - $buf_dly}]
    set buf_per_stage [expr {$buf_cnt > 0 ? double($buf_dly) / $buf_cnt : 0}]
    
    # Count number of '1' bits in select pattern (stages where buffer is active)
    set active_stages 0
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {[string index $select_pattern [expr {$num_cascades - 1 - $i}]] == "1"} {
            incr active_stages
        }
    }
    
    puts $tbl_fh [format "| %3d | %6s | %5s | %5s | %4s | %12s | %9.1f | %9s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $logic_delay $buf_per_stage $active_stages]
}

puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "FALL TRANSITION ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "| Cfg | Select | Total | Buffer       | Logic/Wire   | Buffer    | Effective |"
puts $tbl_fh "|     | Pattern| Delay | Count | Delay| Delay        | per Stage | Stages    |"
puts $tbl_fh "|     |        | (ps)  |       | (ps) | (ps)         | (ps)      | Active    |"
puts $tbl_fh "=================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    lassign $fall_data($config) total buf_cnt buf_dly
    
    set logic_delay [expr {$total - $buf_dly}]
    set buf_per_stage [expr {$buf_cnt > 0 ? double($buf_dly) / $buf_cnt : 0}]
    
    # Count number of '1' bits in select pattern
    set active_stages 0
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {[string index $select_pattern [expr {$num_cascades - 1 - $i}]] == "1"} {
            incr active_stages
        }
    }
    
    puts $tbl_fh [format "| %3d | %6s | %5s | %5s | %4s | %12s | %9.1f | %9s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $logic_delay $buf_per_stage $active_stages]
}

puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "LEGEND:"
puts $tbl_fh "  Cfg           - Configuration number (0 to [expr {$total_configs - 1}])"
puts $tbl_fh "  Select        - Binary select pattern (MSB to LSB)"
puts $tbl_fh "  Total Delay   - End-to-end path delay in picoseconds"
puts $tbl_fh "  Buffer Count  - Number of BUFV1 buffer cells in the timing path"
puts $tbl_fh "  Buffer Delay  - Total delay contributed by all buffers"
puts $tbl_fh "  Logic/Wire    - Delay from muxes, interconnect, and parasitics"
puts $tbl_fh "  per Stage     - Average buffer delay per stage"
puts $tbl_fh "  Active Stages - Number of '1' bits in select (stages with buffer active)"
puts $tbl_fh ""

# Analyze delay variation
puts $tbl_fh "=================================================================================="
puts $tbl_fh "                              DELAY ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""

# Check if delays vary across configurations
set rise_delays {}
set fall_delays {}
for {set config 0} {$config < $total_configs} {incr config} {
    lappend rise_delays [lindex $rise_data($config) 0]
    lappend fall_delays [lindex $fall_data($config) 0]
}

set rise_unique [lsort -unique $rise_delays]
set fall_unique [lsort -unique $fall_delays]

puts $tbl_fh "Rise Transition:"
puts $tbl_fh "  Unique delay values: [llength $rise_unique]"
puts $tbl_fh "  Delays found: $rise_unique ps"
puts $tbl_fh ""
puts $tbl_fh "Fall Transition:"
puts $tbl_fh "  Unique delay values: [llength $fall_unique]"
puts $tbl_fh "  Delays found: $fall_unique ps"
puts $tbl_fh ""

if {[llength $rise_unique] == 1 && [llength $fall_unique] == 1} {
    puts $tbl_fh "⚠ WARNING: DELAY IS CONSTANT ACROSS ALL CONFIGURATIONS!"
    puts $tbl_fh ""
    puts $tbl_fh "PROBLEM ANALYSIS:"
    puts $tbl_fh "  Your current design does NOT function as a programmable delay line."
    puts $tbl_fh "  All paths traverse the same number of gates regardless of select value."
    puts $tbl_fh ""
    puts $tbl_fh "CURRENT DESIGN ISSUE:"
    puts $tbl_fh "  Each stage has structure:"
    puts $tbl_fh "    in -> BUFFER -> MUX(I0=buffered, I1=direct, S=select\[i\]) -> out"
    puts $tbl_fh ""
    puts $tbl_fh "  Problem: Both MUX inputs (I0 and I1) come from the SAME previous stage,"
    puts $tbl_fh "  so selecting different paths doesn't change the number of delays."
    puts $tbl_fh ""
    puts $tbl_fh "RECOMMENDED DESIGN CHANGES:"
    puts $tbl_fh "  Option 1: Bypass Architecture"
    puts $tbl_fh "    - MUX I0: buffered path (current stage)"
    puts $tbl_fh "    - MUX I1: bypass directly from INPUT (skip all previous stages)"
    puts $tbl_fh "    - This creates 2^N different path lengths"
    puts $tbl_fh ""
    puts $tbl_fh "  Option 2: Cascaded Bypass"
    puts $tbl_fh "    - MUX I0: output from previous stage + buffer"
    puts $tbl_fh "    - MUX I1: output from previous stage (no buffer)"
    puts $tbl_fh "    - Each stage can add or skip one buffer delay"
    puts $tbl_fh ""
    puts $tbl_fh "  Option 3: Binary-Weighted Delays"
    puts $tbl_fh "    - Stage 0: 1x unit delay"
    puts $tbl_fh "    - Stage 1: 2x unit delay"
    puts $tbl_fh "    - Stage 2: 4x unit delay"
    puts $tbl_fh "    - Stage N: 2^N unit delay"
    puts $tbl_fh ""
} else {
    set rise_min [lindex [lsort -integer $rise_unique] 0]
    set rise_max [lindex [lsort -integer $rise_unique] end]
    set fall_min [lindex [lsort -integer $fall_unique] 0]
    set fall_max [lindex [lsort -integer $fall_unique] end]
    
    puts $tbl_fh "✓ SUCCESS: Design functions as programmable delay line!"
    puts $tbl_fh ""
    puts $tbl_fh "Delay Range:"
    puts $tbl_fh "  Rise: [expr {$rise_max - $rise_min}] ps ([lindex $rise_unique 0] to [lindex $rise_unique end] ps)"
    puts $tbl_fh "  Fall: [expr {$fall_max - $fall_min}] ps ([lindex $fall_unique 0] to [lindex $fall_unique end] ps)"
    puts $tbl_fh ""
    puts $tbl_fh "Delay Resolution:"
    if {[llength $rise_unique] > 1} {
        set rise_steps {}
        for {set i 1} {$i < [llength $rise_unique]} {incr i} {
            lappend rise_steps [expr {[lindex $rise_unique $i] - [lindex $rise_unique [expr {$i-1}]]}]
        }
        set rise_steps_unique [lsort -unique $rise_steps]
        puts $tbl_fh "  Rise step sizes: $rise_steps_unique ps"
    }
}

puts $tbl_fh ""
puts $tbl_fh "=================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=================================================================================="

# Close files
close $tbl_fh
close $det_fh

puts "\n=========================================="
puts "Delay Analysis Complete"
puts "=========================================="
puts "Reports saved to:"
puts "  Analysis:  $table_file"
puts "  Detailed:  $detailed_file"
puts "=========================================="

# Print summary to console
puts "\nSUMMARY:"
puts "  Total configurations: $total_configs"
puts "  Rise delays: $rise_unique ps"
puts "  Fall delays: $fall_unique ps"

if {[llength $rise_unique] == 1} {
    puts "\n⚠ WARNING: All configurations have identical delay!"
    puts "  This design does NOT work as a programmable delay line."
    puts "  See $table_file for detailed analysis and recommendations."
}

puts "\nDone!\n"