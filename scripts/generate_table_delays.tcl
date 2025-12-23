# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Timing analysis for ladder architecture delay line
# Architecture: Single buffer at input, cascade of 2-input muxes
# =====================================================

puts "\n=========================================="
puts "Generating Ladder Architecture Delay Analysis"
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
puts $tbl_fh "        PROGRAMMABLE DELAY LINE - LADDER ARCHITECTURE ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:      $design(DESIGN)"
puts $tbl_fh "Technology:  $design(TECHNOLOGY)"
puts $tbl_fh "Stages:      $num_cascades"
puts $tbl_fh "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "Architecture Description:"
puts $tbl_fh "  - Single buffer at input creates 'in_buffered' signal"
puts $tbl_fh "  - First MUX (stage 0): selects between 'in' and 'in_buffered'"
puts $tbl_fh "  - Subsequent MUXes (stage 1-N): select between previous MUX output and direct 'in'"
puts $tbl_fh "  - When select\[N\]=1 for N>0, path goes directly from 'in' to that MUX"
puts $tbl_fh ""
puts $tbl_fh "Path Analysis:"
puts $tbl_fh "  - select\[0\]=0: Path uses direct 'in' (no buffer)"
puts $tbl_fh "  - select\[0\]=1: Path includes input buffer"
puts $tbl_fh "  - select\[N\]=1 (N>0): Path bypasses all previous MUXes, goes directly from 'in'"
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

# Function to analyze path characteristics from select pattern
proc analyze_path {select_pattern} {
    set num_stages [string length $select_pattern]
    
    # Check if buffer is used (select[0] in the pattern)
    set uses_buffer [string index $select_pattern [expr {$num_stages - 1}]]
    
    # Find first bypass stage (select[i]=1 for i>0)
    set bypass_stage -1
    for {set stage 1} {$stage < $num_stages} {incr stage} {
        set bit [string index $select_pattern [expr {$num_stages - 1 - $stage}]]
        if {$bit == 1} {
            set bypass_stage $stage
            break
        }
    }
    
    # Count number of muxes in path
    if {$bypass_stage == -1} {
        # No bypass - all muxes are in path
        set mux_count $num_stages
    } else {
        # Bypass at stage N means: 1 mux at bypass stage + remaining muxes after it
        set mux_count [expr {$num_stages - $bypass_stage}]
    }
    
    return [list $uses_buffer $mux_count]
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
puts "Using -through constraints to trace actual paths...\n"

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

# Get buffer instance
set buffer_inst [get_db insts -if {.base_cell.base_name == BUFV1_140P9T30R}]
if {[llength $buffer_inst] == 0} {
    puts "ERROR: Could not find input buffer"
    close $tbl_fh
    close $det_fh
    return
}
puts "Found input buffer: [get_db $buffer_inst .name]"

# Data structures to store results
array set rise_data {}
array set fall_data {}
array set path_info {}

# Analyze each configuration
for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [binary_to_select $config $num_cascades]
    
    lassign [analyze_path $select_pattern] uses_buf expected_muxes
    set path_info($config) [list $select_pattern $uses_buf $expected_muxes]
    
    puts "Config $config: select=$select_pattern | Buffer=$uses_buf | Expected MUXes=$expected_muxes"
    
    # Build -through constraints based on select bits
    set through_pins_list {}
    
    # Find the first stage where select=1 (for stages > 0)
    # This stage bypasses directly to 'in'
    set bypass_stage -1
    for {set stage 1} {$stage < $num_cascades} {incr stage} {
        set sel_bit [string index $select_pattern [expr {$num_cascades - 1 - $stage}]]
        if {$sel_bit == 1} {
            set bypass_stage $stage
            break
        }
    }
    
    if {$bypass_stage == -1} {
        # No bypass - path goes through all MUXes sequentially
        for {set stage 0} {$stage < $num_cascades} {incr stage} {
            set sel_bit [string index $select_pattern [expr {$num_cascades - 1 - $stage}]]
            set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"
            
            if {$stage == 0} {
                # First mux: I0=in, I1=in_buffered
                if {$sel_bit == 0} {
                    set through_pin "${mux_name}/I0"
                } else {
                    set through_pin "${mux_name}/I1"
                }
            } else {
                # Subsequent muxes: always use I0 (previous mux output)
                set through_pin "${mux_name}/I0"
            }
            
            lappend through_pins_list $through_pin
        }
    } else {
        # Path bypasses at bypass_stage - goes directly from 'in' to that stage
        # Only add through constraint for the bypass stage
        set mux_name "DELAY_STAGES\\\[$bypass_stage\\\].genblk1.mux_inst"
        set through_pin "${mux_name}/I1"
        lappend through_pins_list $through_pin
        
        # Then continue through subsequent stages using I0
        for {set stage [expr {$bypass_stage + 1}]} {$stage < $num_cascades} {incr stage} {
            set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"
            set through_pin "${mux_name}/I0"
            lappend through_pins_list $through_pin
        }
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
            puts $det_fh "ERROR: Could not generate timing path"
            
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
            puts $det_fh "Expected: Buffer=$uses_buf, MUXes=$expected_muxes"
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
puts $tbl_fh "=============================================================================================="
puts $tbl_fh "| Cfg | Select  | Total | Buffers  | Muxes     | Other  | Exp   | Exp | Buf | Mux |"
puts $tbl_fh "|     | Pattern | Delay | Cnt | Dly| Cnt |  Dly| Delay  | Buf   | Mux | OK? | OK? |"
puts $tbl_fh "|     |         | (ps)  |     |(ps)|     | (ps)| (ps)   |       |     |     |     |"
puts $tbl_fh "=============================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $path_info($config) select_pattern uses_buf expected_muxes
    lassign $rise_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_match [expr {$buf_cnt == $uses_buf ? "Y" : "N"}]
    set mux_match [expr {$mux_cnt == $expected_muxes ? "Y" : "N"}]
    
    puts $tbl_fh [format "| %3d | %7s | %5s | %3s | %3s| %3s | %4s| %6s | %5s | %3s | %3s | %3s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $uses_buf $expected_muxes $buf_match $mux_match]
}

puts $tbl_fh "=============================================================================================="
puts $tbl_fh ""
puts $tbl_fh "FALL TRANSITION ANALYSIS"
puts $tbl_fh "=============================================================================================="
puts $tbl_fh "| Cfg | Select  | Total | Buffers  | Muxes     | Other  | Exp   | Exp | Buf | Mux |"
puts $tbl_fh "|     | Pattern | Delay | Cnt | Dly| Cnt |  Dly| Delay  | Buf   | Mux | OK? | OK? |"
puts $tbl_fh "|     |         | (ps)  |     |(ps)|     | (ps)| (ps)   |       |     |     |     |"
puts $tbl_fh "=============================================================================================="

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $path_info($config) select_pattern uses_buf expected_muxes
    lassign $fall_data($config) total buf_cnt buf_dly mux_cnt mux_dly
    
    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_match [expr {$buf_cnt == $uses_buf ? "Y" : "N"}]
    set mux_match [expr {$mux_cnt == $expected_muxes ? "Y" : "N"}]
    
    puts $tbl_fh [format "| %3d | %7s | %5s | %3s | %3s| %3s | %4s| %6s | %5s | %3s | %3s | %3s |" \
        $config $select_pattern $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $uses_buf $expected_muxes $buf_match $mux_match]
}

puts $tbl_fh "=============================================================================================="
puts $tbl_fh ""
puts $tbl_fh "LEGEND:"
puts $tbl_fh "  Cfg         - Configuration number"
puts $tbl_fh "  Select      - Binary select pattern (MSB to LSB)"
puts $tbl_fh "  Total Delay - End-to-end path delay in picoseconds"
puts $tbl_fh "  Buffers     - Number and total delay of buffer instances in path"
puts $tbl_fh "  Muxes       - Number and total delay of mux instances in path"
puts $tbl_fh "  Other       - Remaining delay (interconnect, parasitics)"
puts $tbl_fh "  Exp Buf     - Expected number of buffers (0 or 1)"
puts $tbl_fh "  Exp Mux     - Expected number of muxes in path"
puts $tbl_fh "  Buf OK?     - Does buffer count match expected? (Y/N)"
puts $tbl_fh "  Mux OK?     - Does mux count match expected? (Y/N)"
puts $tbl_fh ""

# Analyze delay variation
puts $tbl_fh "=============================================================================================="
puts $tbl_fh "                              DELAY ANALYSIS SUMMARY"
puts $tbl_fh "=============================================================================================="
puts $tbl_fh ""

# Collect all delays
set rise_delays {}
set fall_delays {}

for {set config 0} {$config < $total_configs} {incr config} {
    lappend rise_delays [lindex $rise_data($config) 0]
    lappend fall_delays [lindex $fall_data($config) 0]
}

set rise_unique [lsort -unique -integer $rise_delays]
set fall_unique [lsort -unique -integer $fall_delays]

puts $tbl_fh "Rise Transition:"
puts $tbl_fh "  Unique delay values: [llength $rise_unique]"
puts $tbl_fh "  Delay values: $rise_unique ps"
puts $tbl_fh ""
puts $tbl_fh "Fall Transition:"
puts $tbl_fh "  Unique delay values: [llength $fall_unique]"
puts $tbl_fh "  Delay values: $fall_unique ps"
puts $tbl_fh ""

if {[llength $rise_unique] > 1} {
    set rise_min [lindex $rise_unique 0]
    set rise_max [lindex $rise_unique end]
    set fall_min [lindex $fall_unique 0]
    set fall_max [lindex $fall_unique end]
    
    puts $tbl_fh "✓ SUCCESS: Ladder architecture working!"
    puts $tbl_fh ""
    puts $tbl_fh "Delay Range:"
    puts $tbl_fh "  Rise: [expr {$rise_max - $rise_min}] ps (${rise_min} to ${rise_max} ps)"
    puts $tbl_fh "  Fall: [expr {$fall_max - $fall_min}] ps (${fall_min} to ${fall_max} ps)"
    puts $tbl_fh ""
    
    # Calculate average MUX delay
    set mux_delays {}
    for {set idx 1} {$idx < [llength $rise_unique]} {incr idx} {
        set diff [expr {[lindex $rise_unique $idx] - [lindex $rise_unique [expr {$idx-1}]]}]
        lappend mux_delays $diff
    }
    if {[llength $mux_delays] > 0} {
        set avg_mux_delay [expr {([lindex $rise_unique end] - [lindex $rise_unique 0]) / double([llength $mux_delays])}]
        puts $tbl_fh "Average MUX delay step: [format %.1f $avg_mux_delay] ps"
    }
} else {
    puts $tbl_fh "⚠ WARNING: All configurations have identical delay!"
    puts $tbl_fh "Check detailed timing report for path analysis."
}

puts $tbl_fh ""
puts $tbl_fh "=============================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=============================================================================================="

# Close files
close $tbl_fh
close $det_fh

puts "\n=========================================="
puts "Ladder Architecture Analysis Complete"
puts "=========================================="
puts "Reports saved to:"
puts "  Analysis:  $table_file"
puts "  Detailed:  $detailed_file"
puts "=========================================="

# Print summary to console
puts "\nSUMMARY:"
puts "  Architecture: Ladder (1 buffer, $num_cascades cascaded muxes)"
puts "  Total configurations: $total_configs"
puts "  Unique rise delays: [llength $rise_unique]"
puts "  Rise delays: $rise_unique ps"

if {[llength $rise_unique] > 1} {
    puts "\n✓ SUCCESS: Variable delays achieved!"
    puts "  Delay range (rise): [expr {[lindex $rise_unique end] - [lindex $rise_unique 0]}] ps"
    puts "  Number of delay steps: [llength $rise_unique]"
} else {
    puts "\n⚠ WARNING: Constant delay across all configurations"
}

puts "\nDone!\n"