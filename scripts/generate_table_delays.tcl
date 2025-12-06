# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Detailed timing analysis for programmable delay line
# Uses -through to force specific mux paths based on select bits
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

puts "Auto-detected $num_cascades cascade stages from select\\\[$num_cascades-1:0\\\] pins"

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
puts $tbl_fh "Analysis Method: Using -through options to force specific mux paths"
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

# Function to extract timing info from report
proc extract_timing_info {report_text} {
    set total_delay 0
    set buffer_count 0
    set buffer_delay 0
    set mux_count 0
    set mux_delay 0
    
    set lines [split $report_text "\n"]
    
    # Find total delay from "Data Path:-" line
    foreach line $lines {
        if {[regexp {Data Path:-\s+(\d+)} $line match delay]} {
            set total_delay $delay
        }
    }
    
    # Count buffers and muxes and their delays
    foreach line $lines {
        # Match buffer: BUFV1_140P9T30R with delay extraction
        if {[regexp {BUFV1_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr buffer_count
            set buffer_delay [expr {$buffer_delay + $delay}]
        }
        # Match mux: CLKMUX2V0_140P9T30R with delay extraction
        if {[regexp {CLKMUX2V0_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr mux_count
            set mux_delay [expr {$mux_delay + $delay}]
        }
    }
    
    return [list $total_delay $buffer_count $buffer_delay $mux_count $mux_delay]
}

# Calculate total number of configurations
set total_configs [expr {1 << $num_cascades}]

puts "Analyzing $total_configs different select configurations..."
puts "Using -through constraints to force specific mux input paths...\n"

# Get input and output ports
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find input/output ports"
    close $tbl_fh
    close $det_fh
    return
}

# Get all mux instances
set all_muxes [get_db insts -if {.base_cell.base_name == CLKMUX2V0_140P9T30R}]
set num_muxes [llength $all_muxes]

puts "Found $num_muxes mux instances in design"

if {$num_muxes != $num_cascades} {
    puts "WARNING: Number of muxes ($num_muxes) doesn't match cascades ($num_cascades)"
}

# Data structures to store results
array set rise_data {}
array set fall_data {}

# Analyze each configuration
for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    
    puts "Processing configuration $config: select = $select_pattern"
    
    # Build -through constraints based on select bits
    # For each mux, select I0 (direct) or I1 (buffered) based on select bit
    set through_pins_list {}
    
    for {set stage 0} {$stage < $num_cascades} {incr stage} {
        # Get the mux for this stage
        set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"
        
        # Determine which input to use based on select bit
        set sel_bit [string index $select_pattern [expr {$num_cascades - 1 - $stage}]]
        
        if {$sel_bit == 0} {
            # Use I0 (direct path, no buffer)
            set through_pin "${mux_name}/I0"
        } else {
            # Use I1 (buffered path)
            set through_pin "${mux_name}/I1"
        }
        
        lappend through_pins_list $through_pin
    }
    
    # Analyze both transitions
    foreach transition {rise fall} {
        if {$transition == "rise"} {
            set from_opt "-from_rise"
            set to_opt "-to_rise"
        } else {
            set from_opt "-from_fall"
            set to_opt "-to_fall"
        }
        
        # Build report_timing command with -through options
        set report_file "${design(REPORT_DIR)}/temp_timing_${config}_${transition}.rpt"
        
        # Construct the full command
        set cmd "report_timing $from_opt \$in_port $to_opt \$out_port"
        
        # Add -through for each mux input pin
        foreach pin $through_pins_list {
            append cmd " -through \[get_db pins $pin\]"
        }
        
        append cmd " -unconstrained -path_type full -max_paths 1 > $report_file"
        
        # Execute the command
        if {[catch {eval $cmd} err]} {
            puts "WARNING: Timing report failed for config $config, $transition: $err"
            puts $det_fh "\n=========================================="
            puts $det_fh "Config: $config | Select: $select_pattern | Transition: $transition"
            puts $det_fh "=========================================="
            puts $det_fh "ERROR: Could not generate timing path with specified -through constraints"
            puts $det_fh "This may indicate the path doesn't exist or is optimized away"
            
            # Store error data
            if {$transition == "rise"} {
                set rise_data($config) [list 0 0 0 0 0]
            } else {
                set fall_data($config) [list 0 0 0 0 0]
            }
            continue
        }
        
        # Read the report
        if {[file exists $report_file]} {
            set temp_fh [open $report_file "r"]
            set report_content [read $temp_fh]
            close $temp_fh
            
            # Save detailed report
            puts $det_fh "\n=========================================="
            puts $det_fh "Config: $config | Select: $select_pattern | Transition: $transition"
            puts $det_fh "Through pins: $through_pins_list"
            puts $det_fh "=========================================="
            puts $det_fh $report_content
            
            # Extract path details
            lassign [extract_timing_info $report_content] total_delay buf_cnt buf_dly mux_cnt mux_dly
            
            # Store data
            if {$transition == "rise"} {
                set rise_data($config) [list $total_delay $buf_cnt $buf_dly $mux_cnt $mux_dly]
            } else {
                set fall_data($config) [list $total_delay $buf_cnt $buf_dly $mux_cnt $mux_dly]
            }
            
            # Remove temporary file
            file delete $report_file
        } else {
            puts "ERROR: Report file not created for config $config, $transition"
            if {$transition == "rise"} {
                set rise_data($config) [list 0 0 0 0 0]
            } else {
                set fall_data($config) [list 0 0 0 0 0]
            }
        }
    }
}

# Write detailed results table
puts $tbl_fh "RISE TRANSITION ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "| Cfg | Select  | Total | Buffers  | Muxes    | Logic/Wire | Buf/Stg | Active |"
puts $tbl_fh "|     | Pattern | Delay | Cnt | Dly| Cnt | Dly| Delay      | (ps)    | Stages |"
puts $tbl_fh "|     |         | (ps)  |     |(ps)|     |(ps)| (ps)       |         |        |"
puts $tbl_fh "=================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    lassign $rise_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_per_stage [expr {$buf_cnt > 0 ? double($buf_dly) / $buf_cnt : 0}]
    
    # Count active stages (number of '1' bits)
    set active_stages 0
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {[string index $select_pattern [expr {$num_cascades - 1 - $i}]] == "1"} {
            incr active_stages
        }
    }
    
    puts $tbl_fh [format "| %3d | %6s| %5s | %3s | %3s| %3s | %3s| %10s | %7.1f | %6s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $buf_per_stage $active_stages]
}

puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "FALL TRANSITION ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "| Cfg | Select  | Total | Buffers  | Muxes    | Logic/Wire | Buf/Stg | Active |"
puts $tbl_fh "|     | Pattern | Delay | Cnt | Dly| Cnt | Dly| Delay      | (ps)    | Stages |"
puts $tbl_fh "|     |         | (ps)  |     |(ps)|     |(ps)| (ps)       |         |        |"
puts $tbl_fh "=================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    lassign $fall_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_per_stage [expr {$buf_cnt > 0 ? double($buf_dly) / $buf_cnt : 0}]
    
    # Count active stages
    set active_stages 0
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {[string index $select_pattern [expr {$num_cascades - 1 - $i}]] == "1"} {
            incr active_stages
        }
    }
    
    puts $tbl_fh [format "| %3d | %6s| %5s | %3s | %3s| %3s | %3s| %10s | %7.1f | %6s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $buf_per_stage $active_stages]
}

puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "LEGEND:"
puts $tbl_fh "  Cfg         - Configuration number (0 to [expr {$total_configs - 1}])"
puts $tbl_fh "  Select      - Binary select pattern (MSB to LSB)"
puts $tbl_fh "  Total Delay - End-to-end path delay in picoseconds"
puts $tbl_fh "  Buffers     - Number and total delay of BUFV1 buffer cells"
puts $tbl_fh "  Muxes       - Number and total delay of CLKMUX2V0 mux cells"
puts $tbl_fh "  Logic/Wire  - Remaining delay (interconnect, parasitics)"
puts $tbl_fh "  Buf/Stg     - Average buffer delay per buffer instance"
puts $tbl_fh "  Active      - Number of '1' bits in select (expected # of buffers)"
puts $tbl_fh ""

# Analyze delay variation
puts $tbl_fh "=================================================================================="
puts $tbl_fh "                              DELAY ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""

# Collect all delays
set rise_delays {}
set fall_delays {}
set rise_buf_counts {}
set fall_buf_counts {}

for {set config 0} {$config < $total_configs} {incr config} {
    lappend rise_delays [lindex $rise_data($config) 0]
    lappend fall_delays [lindex $fall_data($config) 0]
    lappend rise_buf_counts [lindex $rise_data($config) 1]
    lappend fall_buf_counts [lindex $fall_data($config) 1]
}

set rise_unique [lsort -unique -integer $rise_delays]
set fall_unique [lsort -unique -integer $fall_delays]
set rise_buf_unique [lsort -unique -integer $rise_buf_counts]
set fall_buf_unique [lsort -unique -integer $fall_buf_counts]

puts $tbl_fh "Rise Transition:"
puts $tbl_fh "  Unique delay values: [llength $rise_unique]"
puts $tbl_fh "  Delay range: $rise_unique ps"
puts $tbl_fh "  Buffer counts found: $rise_buf_unique"
puts $tbl_fh ""
puts $tbl_fh "Fall Transition:"
puts $tbl_fh "  Unique delay values: [llength $fall_unique]"
puts $tbl_fh "  Delay range: $fall_unique ps"
puts $tbl_fh "  Buffer counts found: $fall_buf_unique"
puts $tbl_fh ""

if {[llength $rise_unique] == 1 && [llength $fall_unique] == 1} {
    puts $tbl_fh "⚠ WARNING: DELAY IS STILL CONSTANT!"
    puts $tbl_fh ""
    puts $tbl_fh "Possible reasons:"
    puts $tbl_fh "  1. All -through constraints resulted in same path"
    puts $tbl_fh "  2. Synthesis optimized away different paths"
    puts $tbl_fh "  3. SDC constraints not preventing optimization"
    puts $tbl_fh "  4. Mux instances not properly named/found"
    puts $tbl_fh ""
    puts $tbl_fh "Check timing_paths_detailed.rpt to see which pins were used"
} else {
    set rise_min [lindex $rise_unique 0]
    set rise_max [lindex $rise_unique end]
    set fall_min [lindex $fall_unique 0]
    set fall_max [lindex $fall_unique end]
    
    puts $tbl_fh "✓ SUCCESS: Programmable delay line working!"
    puts $tbl_fh ""
    puts $tbl_fh "Delay Range:"
    puts $tbl_fh "  Rise: [expr {$rise_max - $rise_min}] ps (${rise_min} to ${rise_max} ps)"
    puts $tbl_fh "  Fall: [expr {$fall_max - $fall_min}] ps (${fall_min} to ${fall_max} ps)"
    puts $tbl_fh ""
    puts $tbl_fh "Buffer Count Range:"
    puts $tbl_fh "  Rise: [lindex $rise_buf_unique 0] to [lindex $rise_buf_unique end] buffers"
    puts $tbl_fh "  Fall: [lindex $fall_buf_unique 0] to [lindex $fall_buf_unique end] buffers"
    puts $tbl_fh ""
    
    # Calculate delay per buffer
    if {[llength $rise_unique] > 1} {
        set delay_step [expr {([lindex $rise_unique end] - [lindex $rise_unique 0]) / double([lindex $rise_buf_unique end] - [lindex $rise_buf_unique 0])}]
        puts $tbl_fh "Average delay per buffer: [format %.1f $delay_step] ps"
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
puts "  Rise buffer counts: $rise_buf_unique"
puts "  Fall buffer counts: $fall_buf_unique"

if {[llength $rise_unique] > 1} {
    puts "\n✓ SUCCESS: Design shows variable delays!"
    puts "  Delay range (rise): [expr {[lindex $rise_unique end] - [lindex $rise_unique 0]}] ps"
} else {
    puts "\n⚠ WARNING: All configurations still have identical delay"
    puts "  Check detailed report for -through constraint results"
}

puts "\nDone!\n"