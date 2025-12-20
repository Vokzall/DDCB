# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Detailed timing analysis for programmable delay line with 3-input MUX
# Uses -through to force specific mux paths based on 2-bit select (S0, S1)
# =====================================================

puts "\n=========================================="
puts "Generating Detailed Delay Analysis (3-Input MUX)"
puts "=========================================="

# Create reports directory if it doesn't exist
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

# Auto-detect number of cascades by counting select pins
set select_pins [get_db ports select*]
set num_select_bits [llength $select_pins]

if {$num_select_bits == 0} {
    puts "ERROR: Could not detect select pins. Design might not be elaborated properly."
    return
}

# For 3-input MUX, we need 2 bits per stage
set num_cascades [expr {$num_select_bits / 2}]

puts "Auto-detected $num_select_bits select bits"
puts "Number of cascade stages: $num_cascades (2 bits per stage)"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

# Open files for writing
set tbl_fh [open $table_file "w"]
set det_fh [open $detailed_file "w"]

# Write table headers
puts $tbl_fh "=================================================================================="
puts $tbl_fh "     PROGRAMMABLE DELAY LINE - 3-INPUT MUX TIMING ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:      $design(DESIGN)"
puts $tbl_fh "Technology:  $design(TECHNOLOGY)"
puts $tbl_fh "Stages:      $num_cascades"
puts $tbl_fh "Select bits: $num_select_bits (2 bits per stage)"
puts $tbl_fh "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "MUX Configuration:"
puts $tbl_fh "  I2 - Direct path (0 buffers)    : S1=0, S0=0"
puts $tbl_fh "  I1 - Single buffer path (1 buf) : S1=0, S0=1"
puts $tbl_fh "  I0 - Double buffer path (2 buf) : S1=1, S0=0"
puts $tbl_fh ""
puts $tbl_fh "Analysis Method: Using -through options to force specific mux paths"
puts $tbl_fh ""

# Function to convert configuration to select pattern (S0, S1 pairs)
proc config_to_select {config num_stages} {
    set pattern ""
    for {set stage 0} {$stage < $num_stages} {incr stage} {
        # Extract 2 bits for this stage
        set stage_config [expr {($config >> ($stage * 2)) & 0x3}]
        
        # Convert to S0, S1
        set s0 [expr {$stage_config & 0x1}]
        set s1 [expr {($stage_config >> 1) & 0x1}]
        
        append pattern "${s1}${s0}"
    }
    return $pattern
}

# Function to get mux input and expected buffer count
proc get_mux_input {s1 s0} {
    if {$s1 == 0 && $s0 == 0} {
        return [list "I2" 0]  ;# Direct path
    } elseif {$s1 == 0 && $s0 == 1} {
        return [list "I1" 1]  ;# 1 buffer
    } elseif {$s1 == 1 && $s0 == 0} {
        return [list "I0" 2]  ;# 2 buffers
    } else {
        return [list "I0" 2]  ;# Invalid, default to I0
    }
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
        # Match 3-input mux: MUX3V4_140P9T30R with delay extraction
        if {[regexp {MUX3V4_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr mux_count
            set mux_delay [expr {$mux_delay + $delay}]
        }
    }
    
    return [list $total_delay $buffer_count $buffer_delay $mux_count $mux_delay]
}

# Calculate total number of configurations (3 options per stage)
set total_configs [expr {int(pow(3, $num_cascades))}]

puts "Analyzing $total_configs different configurations (3^$num_cascades)..."
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
set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set num_muxes [llength $all_muxes]

puts "Found $num_muxes mux instances in design"

if {$num_muxes != $num_cascades} {
    puts "WARNING: Number of muxes ($num_muxes) doesn't match cascades ($num_cascades)"
}

# Data structures to store results
array set rise_data {}
array set fall_data {}
array set config_info {}

# Analyze each configuration
for {set config 0} {$config < $total_configs} {incr config} {
    # Build configuration string and through pins
    set through_pins_list {}
    set config_desc ""
    set expected_buffers 0
    
    for {set stage 0} {$stage < $num_cascades} {incr stage} {
        # Extract 2 bits for this stage
        set stage_val [expr {($config / int(pow(3, $stage))) % 3}]
        
        # Determine S0, S1 based on stage value
        if {$stage_val == 0} {
            set s0 0; set s1 0  ;# I2 (0 buffers)
        } elseif {$stage_val == 1} {
            set s0 1; set s1 0  ;# I1 (1 buffer)
        } else {
            set s0 0; set s1 1  ;# I0 (2 buffers)
        }
        
        lassign [get_mux_input $s1 $s0] input_pin buf_cnt
        set expected_buffers [expr {$expected_buffers + $buf_cnt}]
        
        # Get the mux for this stage
        set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"
        set through_pin "${mux_name}/${input_pin}"
        
        lappend through_pins_list $through_pin
        append config_desc "S${stage}:${s1}${s0} "
    }
    
    set config_info($config) [list $config_desc $expected_buffers]
    
    puts "Config $config: $config_desc (Expected: $expected_buffers buffers)"
    
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
            puts $det_fh "Config: $config | $config_desc | Transition: $transition"
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
            puts $det_fh "Config: $config | $config_desc"
            puts $det_fh "Transition: $transition | Expected buffers: $expected_buffers"
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
puts $tbl_fh "=========================================================================================="
puts $tbl_fh "| Cfg | Configuration     | Total | Buffers   | Muxes     | Logic/Wire | Exp | Match? |"
puts $tbl_fh "|     |                   | Delay | Cnt |  Dly| Cnt |  Dly| Delay      | Buf |        |"
puts $tbl_fh "|     |                   | (ps)  |     | (ps)|     | (ps)| (ps)       |     |        |"
puts $tbl_fh "=========================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $config_info($config) config_desc expected_buffers
    lassign $rise_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set match [expr {$buf_cnt == $expected_buffers ? "YES" : "NO"}]
    
    puts $tbl_fh [format "| %3d | %-17s | %5s | %3s | %4s| %3s | %4s| %10s | %3s | %6s |" \
        $config $config_desc $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $expected_buffers $match]
}

puts $tbl_fh "=========================================================================================="
puts $tbl_fh ""
puts $tbl_fh "FALL TRANSITION ANALYSIS"
puts $tbl_fh "=========================================================================================="
puts $tbl_fh "| Cfg | Configuration     | Total | Buffers   | Muxes     | Logic/Wire | Exp | Match? |"
puts $tbl_fh "|     |                   | Delay | Cnt |  Dly| Cnt |  Dly| Delay      | Buf |        |"
puts $tbl_fh "|     |                   | (ps)  |     | (ps)|     | (ps)| (ps)       |     |        |"
puts $tbl_fh "=========================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $config_info($config) config_desc expected_buffers
    lassign $fall_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set match [expr {$buf_cnt == $expected_buffers ? "YES" : "NO"}]
    
    puts $tbl_fh [format "| %3d | %-17s | %5s | %3s | %4s| %3s | %4s| %10s | %3s | %6s |" \
        $config $config_desc $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $expected_buffers $match]
}

puts $tbl_fh "=========================================================================================="
puts $tbl_fh ""
puts $tbl_fh "LEGEND:"
puts $tbl_fh "  Cfg           - Configuration number (0 to [expr {$total_configs - 1}])"
puts $tbl_fh "  Configuration - Select signals for each stage (S0:S1S0 format)"
puts $tbl_fh "  Total Delay   - End-to-end path delay in picoseconds"
puts $tbl_fh "  Buffers       - Number and total delay of BUFV1 buffer cells"
puts $tbl_fh "  Muxes         - Number and total delay of MUX3V4 mux cells"
puts $tbl_fh "  Logic/Wire    - Remaining delay (interconnect, parasitics)"
puts $tbl_fh "  Exp Buf       - Expected number of buffers for this configuration"
puts $tbl_fh "  Match?        - Does actual buffer count match expected?"
puts $tbl_fh ""
puts $tbl_fh "MUX Input Selection:"
puts $tbl_fh "  S1=0, S0=0 -> I2 (0 buffers, direct path)"
puts $tbl_fh "  S1=0, S0=1 -> I1 (1 buffer)"
puts $tbl_fh "  S1=1, S0=0 -> I0 (2 buffers)"
puts $tbl_fh ""

# Analyze delay variation
puts $tbl_fh "=========================================================================================="
puts $tbl_fh "                              DELAY ANALYSIS"
puts $tbl_fh "=========================================================================================="
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
puts $tbl_fh "  Delay values: $rise_unique ps"
puts $tbl_fh "  Buffer counts found: $rise_buf_unique"
puts $tbl_fh ""
puts $tbl_fh "Fall Transition:"
puts $tbl_fh "  Unique delay values: [llength $fall_unique]"
puts $tbl_fh "  Delay values: $fall_unique ps"
puts $tbl_fh "  Buffer counts found: $fall_buf_unique"
puts $tbl_fh ""

if {[llength $rise_unique] == 1 && [llength $fall_unique] == 1} {
    puts $tbl_fh "⚠ WARNING: DELAY IS CONSTANT!"
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
    
    # Calculate delay steps
    if {[llength $rise_unique] > 2} {
        set delays_sorted [lsort -integer $rise_unique]
        set steps {}
        for {set i 1} {$i < [llength $delays_sorted]} {incr i} {
            set step [expr {[lindex $delays_sorted $i] - [lindex $delays_sorted [expr {$i-1}]]}]
            lappend steps $step
        }
        set steps_unique [lsort -unique -integer $steps]
        puts $tbl_fh "Delay steps between consecutive configurations: $steps_unique ps"
    }
}

puts $tbl_fh ""
puts $tbl_fh "=========================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=========================================================================================="

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
puts "  Total configurations: $total_configs (3^$num_cascades)"
puts "  Unique rise delays: [llength $rise_unique]"
puts "  Unique fall delays: [llength $fall_unique]"
puts "  Rise delays: $rise_unique ps"
puts "  Fall delays: $fall_unique ps"

if {[llength $rise_unique] > 1} {
    puts "\n✓ SUCCESS: Design shows variable delays!"
    puts "  Delay range (rise): [expr {[lindex $rise_unique end] - [lindex $rise_unique 0]}] ps"
    puts "  Number of delay steps: [llength $rise_unique]"
} else {
    puts "\n⚠ WARNING: All configurations have identical delay"
    puts "  Check detailed report for -through constraint results"
}

puts "\nDone!\n"