# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Timing analysis for cascade delay line with 3-input muxes
# Architecture: Cascade of 3-input muxes (MUX3V4_140P9T30R)
#   I0 - bypass (direct from input 'in')
#   I1 - 1 buffer delay (delay_1buf)
#   I2 - 2 buffer delay (delay_2buf)
# Select: 2 bits per stage (S1,S0): 00=I0(bypass), 01=I1, 10/11=I2
# =====================================================

puts "\n=========================================="
puts "Generating Cascade Delay Analysis (3-input MUX)"
puts "=========================================="

# Create reports directory if it doesn't exist
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

# Auto-detect number of cascades by counting select pins
# Each stage has 2 select bits
set select_pins [get_db ports select*]
set num_select_bits [llength $select_pins]
set num_cascades [expr {$num_select_bits / 2}]

if {$num_cascades == 0} {
    puts "ERROR: Could not detect select pins. Design might not be elaborated properly."
    return
}

puts "Auto-detected $num_cascades cascade stages from select\[$num_select_bits-1:0\] pins (2 bits per stage)"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

# Open files for writing
set tbl_fh [open $table_file "w"]
set det_fh [open $detailed_file "w"]

# Write table headers
puts $tbl_fh "=================================================================================="
puts $tbl_fh "        PROGRAMMABLE DELAY LINE - CASCADE 3-INPUT MUX ARCHITECTURE"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:      $design(DESIGN)"
puts $tbl_fh "Technology:  $design(TECHNOLOGY)"
puts $tbl_fh "Stages:      $num_cascades"
puts $tbl_fh "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "Architecture Description (MUX3V4_140P9T30R):"
puts $tbl_fh "  - Each stage has a 3-input mux with 2 select bits (S1,S0)"
puts $tbl_fh "  - I0: bypass - direct connection from input 'in'"
puts $tbl_fh "  - I1: 1 buffer delay (delay_1buf = previous stage output)"
puts $tbl_fh "  - I2: 2 buffer delay (delay_2buf = delay_1buf delayed)"
puts $tbl_fh ""
puts $tbl_fh "Select Logic (S1,S0):"
puts $tbl_fh "  - 00: I0 (bypass from 'in')"
puts $tbl_fh "  - 01: I1 (1 buffer)"
puts $tbl_fh "  - 10: I2 (2 buffers)"
puts $tbl_fh "  - 11: I2 (2 buffers)"
puts $tbl_fh ""
puts $tbl_fh "Path Rules:"
puts $tbl_fh "  - Bypass (I0) takes signal directly from 'in', skipping all previous stages"
puts $tbl_fh "  - After bypass, subsequent stages use I1 or I2 (not another bypass)"
puts $tbl_fh "  - First bypass stage determines the effective path start point"
puts $tbl_fh ""

# Function to convert decimal to binary select pattern (2 bits per stage)
proc decimal_to_select_pattern {value num_stages} {
    set pattern ""
    set width [expr {$num_stages * 2}]
    for {set i [expr {$width - 1}]} {$i >= 0} {incr i -1} {
        set bit [expr {($value >> $i) & 1}]
        append pattern $bit
    }
    return $pattern
}

# Function to decode select bits for a stage
# Returns: 0=I0(bypass), 1=I1, 2=I2
proc decode_mux_input {s1 s0} {
    if {$s1 == 0 && $s0 == 0} {
        return 0  ;# I0 - bypass
    } elseif {$s1 == 0 && $s0 == 1} {
        return 1  ;# I1 - 1 buffer
    } else {
        return 2  ;# I2 - 2 buffers (10 or 11)
    }
}

# Function to analyze path characteristics from select pattern
# Returns: {bypass_stage expected_buffers expected_muxes path_description}
proc analyze_path_3mux {select_pattern num_stages} {
    # Find first bypass stage (where S1S0 = 00)
    set bypass_stage -1
    for {set stage 0} {$stage < $num_stages} {incr stage} {
        set bit_pos [expr {($num_stages - 1 - $stage) * 2}]
        set s1 [string index $select_pattern $bit_pos]
        set s0 [string index $select_pattern [expr {$bit_pos + 1}]]

        if {$s1 == 0 && $s0 == 0} {
            set bypass_stage $stage
            break
        }
    }

    # Calculate expected components in path
    set expected_buffers 0
    set expected_muxes 0
    set path_desc ""

    if {$bypass_stage != -1} {
        # Path starts at bypass stage, goes through remaining stages
        set expected_muxes [expr {$num_stages - $bypass_stage}]

        # Count buffers in stages after bypass
        for {set stage [expr {$bypass_stage + 1}]} {$stage < $num_stages} {incr stage} {
            set bit_pos [expr {($num_stages - 1 - $stage) * 2}]
            set s1 [string index $select_pattern $bit_pos]
            set s0 [string index $select_pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]

            if {$mux_in == 1} {
                incr expected_buffers 1
            } elseif {$mux_in == 2} {
                incr expected_buffers 2
            }
        }
        set path_desc "bypass@$bypass_stage"
    } else {
        # No bypass - path goes through all stages from stage 0
        set expected_muxes $num_stages

        # Count buffers in all stages
        for {set stage 0} {$stage < $num_stages} {incr stage} {
            set bit_pos [expr {($num_stages - 1 - $stage) * 2}]
            set s1 [string index $select_pattern $bit_pos]
            set s0 [string index $select_pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]

            if {$mux_in == 1} {
                incr expected_buffers 1
            } elseif {$mux_in == 2} {
                incr expected_buffers 2
            }
        }
        set path_desc "full_chain"
    }

    return [list $bypass_stage $expected_buffers $expected_muxes $path_desc]
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

# Calculate total number of configurations (2 bits per stage)
set total_configs [expr {1 << ($num_cascades * 2)}]

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
set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set num_muxes [llength $all_muxes]

puts "Found $num_muxes 3-input mux instances in design"

if {$num_muxes != $num_cascades} {
    puts "WARNING: Number of muxes ($num_muxes) doesn't match cascades ($num_cascades)"
}

# Data structures to store results
array set rise_data {}
array set fall_data {}
array set path_info {}

# Analyze each configuration
for {set config 0} {$config < $total_configs} {incr config} {
    set select_pattern [decimal_to_select_pattern $config $num_cascades]

    lassign [analyze_path_3mux $select_pattern $num_cascades] bypass_stage expected_bufs expected_muxes path_desc
    set path_info($config) [list $select_pattern $bypass_stage $expected_bufs $expected_muxes $path_desc]

    puts "Config $config: select=$select_pattern | Bypass=$bypass_stage | Exp Bufs=$expected_bufs | Exp MUXes=$expected_muxes"

    # Build -through constraints based on select bits
    set through_pins_list {}

    if {$bypass_stage != -1} {
        # Path bypasses at bypass_stage - signal goes directly from 'in' to I0 of that stage
        set mux_name "DELAY_STAGES\\\[$bypass_stage\\\].genblk1.mux_inst"
        set through_pin "${mux_name}/I0"
        lappend through_pins_list $through_pin

        # Then continue through subsequent stages using I1 or I2 based on select bits
        for {set stage [expr {$bypass_stage + 1}]} {$stage < $num_cascades} {incr stage} {
            set bit_pos [expr {($num_cascades - 1 - $stage) * 2}]
            set s1 [string index $select_pattern $bit_pos]
            set s0 [string index $select_pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]

            set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"

            # After bypass, signal comes from previous mux output
            # which connects to delay_1buf/delay_2buf of current stage
            if {$mux_in == 0} {
                # This shouldn't happen logically (bypass after bypass)
                # but handle it - use I1 as default path continuation
                set through_pin "${mux_name}/I1"
            } elseif {$mux_in == 1} {
                set through_pin "${mux_name}/I1"
            } else {
                set through_pin "${mux_name}/I2"
            }
            lappend through_pins_list $through_pin
        }
    } else {
        # No bypass - path goes through all MUXes sequentially starting from stage 0
        for {set stage 0} {$stage < $num_cascades} {incr stage} {
            set bit_pos [expr {($num_cascades - 1 - $stage) * 2}]
            set s1 [string index $select_pattern $bit_pos]
            set s0 [string index $select_pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]

            set mux_name "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"

            if {$mux_in == 0} {
                # I0 - bypass (but this is first stage or no bypass found earlier)
                set through_pin "${mux_name}/I0"
            } elseif {$mux_in == 1} {
                set through_pin "${mux_name}/I1"
            } else {
                set through_pin "${mux_name}/I2"
            }
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
            puts $det_fh "Bypass stage: $bypass_stage | Expected: Bufs=$expected_bufs, MUXes=$expected_muxes"
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
puts $tbl_fh "============================================================================================================"
puts $tbl_fh "| Cfg | Select   | Bypass | Total | Buffers  | Muxes     | Other  | Exp   | Exp | Buf | Mux |"
puts $tbl_fh "|     | Pattern  | Stage  | Delay | Cnt | Dly| Cnt |  Dly| Delay  | Buf   | Mux | OK? | OK? |"
puts $tbl_fh "|     |          |        | (ps)  |     |(ps)|     | (ps)| (ps)   |       |     |     |     |"
puts $tbl_fh "============================================================================================================"

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $path_info($config) select_pattern bypass_stage expected_bufs expected_muxes path_desc
    lassign $rise_data($config) total buf_cnt buf_dly mux_cnt mux_dly

    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_match [expr {$buf_cnt == $expected_bufs ? "Y" : "N"}]
    set mux_match [expr {$mux_cnt == $expected_muxes ? "Y" : "N"}]
    set bypass_str [expr {$bypass_stage == -1 ? "none" : $bypass_stage}]

    puts $tbl_fh [format "| %3d | %8s | %6s | %5s | %3s | %3s| %3s | %4s| %6s | %5s | %3s | %3s | %3s |" \
        $config $select_pattern $bypass_str $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $expected_bufs $expected_muxes $buf_match $mux_match]
}

puts $tbl_fh "============================================================================================================"
puts $tbl_fh ""
puts $tbl_fh "FALL TRANSITION ANALYSIS"
puts $tbl_fh "============================================================================================================"
puts $tbl_fh "| Cfg | Select   | Bypass | Total | Buffers  | Muxes     | Other  | Exp   | Exp | Buf | Mux |"
puts $tbl_fh "|     | Pattern  | Stage  | Delay | Cnt | Dly| Cnt |  Dly| Delay  | Buf   | Mux | OK? | OK? |"
puts $tbl_fh "|     |          |        | (ps)  |     |(ps)|     | (ps)| (ps)   |       |     |     |     |"
puts $tbl_fh "============================================================================================================"

for {set config 0} {$config < $total_configs} {incr config} {
    lassign $path_info($config) select_pattern bypass_stage expected_bufs expected_muxes path_desc
    lassign $fall_data($config) total buf_cnt buf_dly mux_cnt mux_dly

    set other_delay [expr {$total - $buf_dly - $mux_dly}]
    set buf_match [expr {$buf_cnt == $expected_bufs ? "Y" : "N"}]
    set mux_match [expr {$mux_cnt == $expected_muxes ? "Y" : "N"}]
    set bypass_str [expr {$bypass_stage == -1 ? "none" : $bypass_stage}]

    puts $tbl_fh [format "| %3d | %8s | %6s | %5s | %3s | %3s| %3s | %4s| %6s | %5s | %3s | %3s | %3s |" \
        $config $select_pattern $bypass_str $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $expected_bufs $expected_muxes $buf_match $mux_match]
}

puts $tbl_fh "============================================================================================================"
puts $tbl_fh ""
puts $tbl_fh "LEGEND:"
puts $tbl_fh "  Cfg         - Configuration number"
puts $tbl_fh "  Select      - Binary select pattern (MSB to LSB, 2 bits per stage: S1S0)"
puts $tbl_fh "                S1S0=00: I0 (bypass), 01: I1 (1 buf), 10/11: I2 (2 buf)"
puts $tbl_fh "  Bypass Stage- Stage where bypass (I0) is selected (-1 = none)"
puts $tbl_fh "  Total Delay - End-to-end path delay in picoseconds"
puts $tbl_fh "  Buffers     - Number and total delay of buffer instances in path"
puts $tbl_fh "  Muxes       - Number and total delay of mux instances in path"
puts $tbl_fh "  Other       - Remaining delay (interconnect, parasitics)"
puts $tbl_fh "  Exp Buf     - Expected number of buffers in path"
puts $tbl_fh "  Exp Mux     - Expected number of muxes in path"
puts $tbl_fh "  Buf OK?     - Does buffer count match expected? (Y/N)"
puts $tbl_fh "  Mux OK?     - Does mux count match expected? (Y/N)"
puts $tbl_fh ""

# Analyze delay variation
puts $tbl_fh "============================================================================================================"
puts $tbl_fh "                              DELAY ANALYSIS SUMMARY"
puts $tbl_fh "============================================================================================================"
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

    puts $tbl_fh "SUCCESS: Cascade 3-input MUX architecture working!"
    puts $tbl_fh ""
    puts $tbl_fh "Delay Range:"
    puts $tbl_fh "  Rise: [expr {$rise_max - $rise_min}] ps (${rise_min} to ${rise_max} ps)"
    puts $tbl_fh "  Fall: [expr {$fall_max - $fall_min}] ps (${fall_min} to ${fall_max} ps)"
    puts $tbl_fh ""

    # Calculate average delay step
    set delay_steps {}
    for {set idx 1} {$idx < [llength $rise_unique]} {incr idx} {
        set diff [expr {[lindex $rise_unique $idx] - [lindex $rise_unique [expr {$idx-1}]]}]
        lappend delay_steps $diff
    }
    if {[llength $delay_steps] > 0} {
        set avg_delay_step [expr {([lindex $rise_unique end] - [lindex $rise_unique 0]) / double([llength $delay_steps])}]
        puts $tbl_fh "Average delay step: [format %.1f $avg_delay_step] ps"
    }
} else {
    puts $tbl_fh "WARNING: All configurations have identical delay!"
    puts $tbl_fh "Check detailed timing report for path analysis."
}

puts $tbl_fh ""
puts $tbl_fh "============================================================================================================"
puts $tbl_fh "End of Analysis"
puts $tbl_fh "============================================================================================================"

# Close files
close $tbl_fh
close $det_fh

puts "\n=========================================="
puts "Cascade 3-MUX Architecture Analysis Complete"
puts "=========================================="
puts "Reports saved to:"
puts "  Analysis:  $table_file"
puts "  Detailed:  $detailed_file"
puts "=========================================="

# Print summary to console
puts "\nSUMMARY:"
puts "  Architecture: Cascade 3-input MUX ($num_cascades stages)"
puts "  Total configurations: $total_configs"
puts "  Unique rise delays: [llength $rise_unique]"
puts "  Rise delays: $rise_unique ps"

if {[llength $rise_unique] > 1} {
    puts "\nSUCCESS: Variable delays achieved!"
    puts "  Delay range (rise): [expr {[lindex $rise_unique end] - [lindex $rise_unique 0]}] ps"
    puts "  Number of delay steps: [llength $rise_unique]"
} else {
    puts "\nWARNING: Constant delay across all configurations"
}

puts "\nDone!\n"
