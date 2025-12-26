# =====================================================
# Script: generate_table_delays_balancer.tcl
# Purpose: Timing analysis for delay_balancer with separate cascade_delays instances
# Generates separate tables for cascade_delays_rise and cascade_delays_fall
# =====================================================

puts "\n=========================================="
puts "Generating Delay Balancer Analysis"
puts "=========================================="

# Create reports directory if it doesn't exist
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

# Auto-detect number of cascades
set select_pins [get_db ports select*]
set num_cascades [llength $select_pins]

if {$num_cascades == 0} {
    puts "ERROR: Could not detect select pins. Design might not be elaborated properly."
    return
}

puts "Auto-detected $num_cascades cascade stages from select\\\[$num_cascades-1:0\\\] pins"

# Output files
set rise_table_file "${design(REPORT_DIR)}/cascade_rise_analysis.txt"
set fall_table_file "${design(REPORT_DIR)}/cascade_fall_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"
set debug_file "${design(REPORT_DIR)}/debug_commands.log"

# Open files for writing
set rise_fh [open $rise_table_file "w"]
set fall_fh [open $fall_table_file "w"]
set det_fh [open $detailed_file "w"]
set dbg_fh [open $debug_file "w"]

puts $dbg_fh "=================================================================================="
puts $dbg_fh "DEBUG LOG - Timing Analysis Commands and Pin Discovery"
puts $dbg_fh "=================================================================================="
puts $dbg_fh "Date: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $dbg_fh ""

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
# Function to extract timing info from report
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
        # Look for Data Path line
        if {[regexp {Data Path:-\s+(\d+)} $line match delay]} {
            set total_delay $delay
            puts "  Extracted total delay: $total_delay ps"
        }
        
        # Count buffers and extract their delays
        if {[regexp {BUFV1_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)} $line match delay]} {
            incr buffer_count
            set buffer_delay [expr {$buffer_delay + $delay}]
        }
        
        # Count muxes and extract their delays
        if {[regexp {CLKMUX2V0_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)} $line match delay]} {
            incr mux_count
            set mux_delay [expr {$mux_delay + $delay}]
        }
    }
    
    return [list $total_delay $buffer_count $buffer_delay $mux_count $mux_delay]
}

# Function to write table header
proc write_table_header {file_handle instance_name num_stages} {
    puts $file_handle "=================================================================================="
    puts $file_handle "    TIMING ANALYSIS FOR: $instance_name"
    puts $file_handle "=================================================================================="
    puts $file_handle "Stages:      $num_stages"
    puts $file_handle "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    puts $file_handle "=================================================================================="
    puts $file_handle ""
    puts $file_handle "Analysis Method: Using -through options to force specific mux paths"
    puts $file_handle ""
    puts $file_handle "=================================================================================="
    puts $file_handle "| Cfg | Select   | Total | Buffers  | Muxes    | Logic/Wire | Buf/Stg | Active |"
    puts $file_handle "|     | Pattern  | Delay | Cnt | Dly| Cnt | Dly| Delay      | (ps)    | Stages |"
    puts $file_handle "|     |          | (ps)  |     |(ps)|     |(ps)| (ps)       |         |        |"
    puts $file_handle "=================================================================================="
}

# Function to analyze a specific cascade_delays instance
proc analyze_cascade_instance {instance_name transition num_cascades in_port out_port det_fh dbg_fh} {
    set total_configs [expr {1 << $num_cascades}]
    array set data_array {}
    
    puts "Analyzing instance: $instance_name with $transition transition..."
    puts $dbg_fh "\n=================================================================================="
    puts $dbg_fh "ANALYZING: $instance_name - $transition transition"
    puts $dbg_fh "=================================================================================="
    
    # Set transition options
    if {$transition == "rise"} {
        set from_opt "-from_rise"
        set to_opt "-to_rise"
    } else {
        set from_opt "-from_fall"
        set to_opt "-to_fall"
    }
    
    # Get the internal input/output of this cascade instance
    puts $dbg_fh "\nSearching for instance pins..."
    puts $dbg_fh "  Looking for: in"
    puts $dbg_fh "  Looking for: out"
    
    set inst_in_pin [get_db ports in]
    set inst_out_pin [get_db ports out]
    
    puts $dbg_fh "  Found input pin:  [llength $inst_in_pin] pins -> $inst_in_pin"
    puts $dbg_fh "  Found output pin: [llength $inst_out_pin] pins -> $inst_out_pin"
    
    if {[llength $inst_in_pin] == 0 || [llength $inst_out_pin] == 0} {
        puts "ERROR: Could not find pins for instance $instance_name"
        puts $dbg_fh "  ERROR: Pins not found!"
        
        # Try alternate naming
        puts $dbg_fh "\nTrying alternate pin naming patterns..."
        set alt_pins [get_db pins ${instance_name}*]
        puts $dbg_fh "  All pins matching '${instance_name}*': $alt_pins"
        
        return [array get data_array]
    }
    
    # Analyze each configuration
    for {set config 0} {$config < $total_configs} {incr config} {
        set select_pattern [binary_to_select $config $num_cascades]
        
        puts "  Config $config: select = $select_pattern"
        
        if {$config == 0} {
            puts $dbg_fh "\nCONFIG $config (First config - detailed debug):"
            puts $dbg_fh "  Select pattern: $select_pattern"
        }
        
        # Build -through constraints based on select bits
        set through_pins_list {}
        
        for {set stage 0} {$stage < $num_cascades} {incr stage} {
            # Construct hierarchical path to mux inside this instance
            # Format: instancename_DELAY_STAGES[X].genblk1.mux_inst/I0 or I1
            set mux_name "${instance_name}_DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst"
            
            # Determine which input to use based on select bit
            set sel_bit [string index $select_pattern [expr {$num_cascades - 1 - $stage}]]
            
            if {$sel_bit == 0} {
                set through_pin "${mux_name}/I0"
            } else {
                set through_pin "${mux_name}/I1"
            }
            
            lappend through_pins_list $through_pin
            
            # Debug first config only
            if {$config == 0} {
                puts $dbg_fh "    Stage $stage: sel_bit=$sel_bit -> $through_pin"
                
                # Try to find this pin
                set found_pin [get_db pins $through_pin]
                puts $dbg_fh "      Found: [llength $found_pin] pins -> $found_pin"
                
                if {[llength $found_pin] == 0} {
                    # Try without escaping
                    set mux_name_unesc "${instance_name}_DELAY_STAGES\[$stage\].genblk1.mux_inst"
                    set through_pin_unesc "${mux_name_unesc}/I0"
                    set found_unesc [get_db pins $through_pin_unesc]
                    puts $dbg_fh "      Tried unescaped: $through_pin_unesc"
                    puts $dbg_fh "      Found: [llength $found_unesc] pins -> $found_unesc"
                }
            }
        }
        
        if {$config == 0} {
            puts $dbg_fh "  Through pins list: $through_pins_list"
        }
        
        # Generate timing report
        global design
        set report_file "${design(REPORT_DIR)}/temp_${instance_name}_${config}_${transition}.rpt"
        
        # Construct the full command
        set cmd "report_timing $from_opt \$inst_in_pin $to_opt \$inst_out_pin"
        
        # Add -through for each mux input pin
        foreach pin $through_pins_list {
            append cmd " -through \[get_db pins $pin\]"
        }
        
        append cmd " -unconstrained -path_type full -max_paths 1 > $report_file"
        
        if {$config == 0} {
            puts $dbg_fh "\nFull report_timing command:"
            puts $dbg_fh "  $cmd"
        }
        
        # Execute the command
        if {[catch {eval $cmd} err]} {
            puts "  WARNING: Timing report failed for config $config: $err"
            
            if {$config == 0} {
                puts $dbg_fh "  ERROR executing command: $err"
            }
            
            puts $det_fh "\n=========================================="
            puts $det_fh "Instance: $instance_name | Config: $config | Select: $select_pattern | Transition: $transition"
            puts $det_fh "=========================================="
            puts $det_fh "ERROR: Could not generate timing path"
            puts $det_fh "Error message: $err"
            
            set data_array($config) [list 0 0 0 0 0]
            continue
        }
        
        # Read the report
        if {[file exists $report_file]} {
            set temp_fh [open $report_file "r"]
            set report_content [read $temp_fh]
            close $temp_fh
            
            # Save detailed report
            puts $det_fh "\n=========================================="
            puts $det_fh "Instance: $instance_name"
            puts $det_fh "Config: $config | Select: $select_pattern | Transition: $transition"
            puts $det_fh "Through pins: $through_pins_list"
            puts $det_fh "=========================================="
            puts $det_fh $report_content
            
            # Extract path details
            lassign [extract_timing_info $report_content] total_delay buf_cnt buf_dly mux_cnt mux_dly
            
            # Store data
            set data_array($config) [list $total_delay $buf_cnt $buf_dly $mux_cnt $mux_dly]
            
            # Remove temporary file
            file delete $report_file
        } else {
            puts "  ERROR: Report file not created for config $config"
            set data_array($config) [list 0 0 0 0 0]
        }
    }
    
    return [array get data_array]
}

# Function to write table data
# Function to write table data
proc write_table_data {file_handle data_list num_cascades} {
    set total_configs [expr {1 << $num_cascades}]
    
    for {set config 0} {$config < $total_configs} {incr config} {
        set select_pattern [binary_to_select $config $num_cascades]
        
        # Get data from the list (which is in {key value key value ...} format)
        set total 0
        set buf_cnt 0
        set buf_dly 0
        set mux_cnt 0
        set mux_dly 0
        
        # Search for the config in the data_list
        for {set i 0} {$i < [llength $data_list]} {incr i 2} {
            set key [lindex $data_list $i]
            if {$key == $config} {
                set val [lindex $data_list [expr {$i + 1}]]
                lassign $val total buf_cnt buf_dly mux_cnt mux_dly
                break
            }
        }
        
        set other_delay [expr {$total - $buf_dly - $mux_dly}]
        set buf_per_stage [expr {$buf_cnt > 0 ? double($buf_dly) / $buf_cnt : 0}]
        
        # Count active stages (number of '1' bits)
        set active_stages 0
        for {set i 0} {$i < $num_cascades} {incr i} {
            if {[string index $select_pattern [expr {$num_cascades - 1 - $i}]] == "1"} {
                incr active_stages
            }
        }
        
        puts $file_handle [format "| %3d | %8s | %5s | %3s | %3s| %3s | %3s| %10s | %7.1f | %6s |" \
            $config $select_pattern $total $buf_cnt $buf_dly $mux_cnt $mux_dly $other_delay $buf_per_stage $active_stages]
    }
    
    puts $file_handle "=================================================================================="
}

# Function to write statistics
# Function to write statistics
proc write_statistics {file_handle data_list num_cascades} {
    set total_configs [expr {1 << $num_cascades}]
    
    # Collect data
    set delays {}
    set buf_counts {}
    
    for {set config 0} {$config < $total_configs} {incr config} {
        # Search for the config in the data_list
        for {set i 0} {$i < [llength $data_list]} {incr i 2} {
            set key [lindex $data_list $i]
            if {$key == $config} {
                set val [lindex $data_list [expr {$i + 1}]]
                lappend delays [lindex $val 0]
                lappend buf_counts [lindex $val 1]
                break
            }
        }
    }
    
    set unique_delays [lsort -unique -integer $delays]
    set unique_buf_counts [lsort -unique -integer $buf_counts]
    
    puts $file_handle ""
    puts $file_handle "STATISTICS:"
    puts $file_handle "  Unique delay values: [llength $unique_delays]"
    puts $file_handle "  Delay range: $unique_delays ps"
    puts $file_handle "  Buffer counts: $unique_buf_counts"
    puts $file_handle ""
    
    if {[llength $unique_delays] > 1} {
        set min_delay [lindex $unique_delays 0]
        set max_delay [lindex $unique_delays end]
        set delay_range [expr {$max_delay - $min_delay}]
        
        puts $file_handle "✓ Variable delay achieved!"
        puts $file_handle "  Min delay: ${min_delay} ps"
        puts $file_handle "  Max delay: ${max_delay} ps"
        puts $file_handle "  Range:     ${delay_range} ps"
        
        if {[llength $unique_buf_counts] > 1} {
            set min_buf [lindex $unique_buf_counts 0]
            set max_buf [lindex $unique_buf_counts end]
            if {[expr {$max_buf - $min_buf}] > 0} {
                set delay_per_buf [expr {double($delay_range) / ($max_buf - $min_buf)}]
                puts $file_handle "  Delay per buffer: [format %.1f $delay_per_buf] ps"
            }
        }
    } else {
        puts $file_handle "⚠ WARNING: Constant delay across all configurations"
    }
    
    puts $file_handle ""
    puts $file_handle "=================================================================================="
}

# Get input and output ports
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find input/output ports"
    close $rise_fh
    close $fall_fh
    close $det_fh
    return
}

puts "\n=========================================="
puts "Analyzing cascade_delays_rise (RISE transition)"
puts "=========================================="

# Write header for rise table
write_table_header $rise_fh "cascade_delays_rise" $num_cascades

# Analyze cascade_delays_rise with RISE transition
array set rise_data [analyze_cascade_instance "cascade_delays_rise" "rise" $num_cascades $in_port $out_port $det_fh $dbg_fh]

# Write rise table data
write_table_data $rise_fh rise_data $num_cascades

# Write rise statistics
write_statistics $rise_fh rise_data $num_cascades

puts $rise_fh ""
puts $rise_fh "LEGEND:"
puts $rise_fh "  Cfg         - Configuration number (0 to [expr {(1 << $num_cascades) - 1}])"
puts $rise_fh "  Select      - Binary select pattern (MSB to LSB)"
puts $rise_fh "  Total Delay - End-to-end delay through cascade_delays_rise"
puts $rise_fh "  Buffers     - Number and total delay of BUFV1 buffer cells"
puts $rise_fh "  Muxes       - Number and total delay of CLKMUX2V0 mux cells"
puts $rise_fh "  Logic/Wire  - Remaining delay (interconnect, parasitics)"
puts $rise_fh "  Buf/Stg     - Average buffer delay per buffer"
puts $rise_fh "  Active      - Number of '1' bits in select"
puts $rise_fh ""
puts $rise_fh "=================================================================================="
puts $rise_fh "End of Analysis for cascade_delays_rise"
puts $rise_fh "=================================================================================="

puts "\n=========================================="
puts "Analyzing cascade_delays_fall (FALL transition)"
puts "=========================================="

# Write header for fall table
write_table_header $fall_fh "cascade_delays_fall" $num_cascades

# Analyze cascade_delays_fall with FALL transition
array set fall_data [analyze_cascade_instance "cascade_delays_fall" "fall" $num_cascades $in_port $out_port $det_fh $dbg_fh]

# Write fall table data
write_table_data $fall_fh fall_data $num_cascades

# Write fall statistics
write_statistics $fall_fh fall_data $num_cascades

puts $fall_fh ""
puts $fall_fh "LEGEND:"
puts $fall_fh "  Cfg         - Configuration number (0 to [expr {(1 << $num_cascades) - 1}])"
puts $fall_fh "  Select      - Binary select pattern (MSB to LSB)"
puts $fall_fh "  Total Delay - End-to-end delay through cascade_delays_fall"
puts $fall_fh "  Buffers     - Number and total delay of BUFV1 buffer cells"
puts $fall_fh "  Muxes       - Number and total delay of CLKMUX2V0 mux cells"
puts $fall_fh "  Logic/Wire  - Remaining delay (interconnect, parasitics)"
puts $fall_fh "  Buf/Stg     - Average buffer delay per buffer"
puts $fall_fh "  Active      - Number of '1' bits in select"
puts $fall_fh ""
puts $fall_fh "=================================================================================="
puts $fall_fh "End of Analysis for cascade_delays_fall"
puts $fall_fh "=================================================================================="

# Close files
close $rise_fh
close $fall_fh
close $det_fh
close $dbg_fh

puts "\n=========================================="
puts "Delay Balancer Analysis Complete"
puts "=========================================="
puts "Reports saved to:"
puts "  Rise cascade:  $rise_table_file"
puts "  Fall cascade:  $fall_table_file"
puts "  Detailed:      $detailed_file"
puts "  Debug log:     $debug_file"
puts "=========================================="

# Print summary
puts "\nSUMMARY:"

# Rise summary
set rise_delays {}
set rise_buf_counts {}
foreach {key val} [array get rise_data] {
    lappend rise_delays [lindex $val 0]
    lappend rise_buf_counts [lindex $val 1]
}
set rise_unique [lsort -unique -integer $rise_delays]
set rise_buf_unique [lsort -unique -integer $rise_buf_counts]

puts "\ncascade_delays_rise (RISE transition):"
puts "  Delay range: $rise_unique ps"
puts "  Buffer counts: $rise_buf_unique"
if {[llength $rise_unique] > 1} {
    puts "  ✓ Variable delays achieved"
} else {
    puts "  ⚠ Constant delay"
}

# Fall summary
set fall_delays {}
set fall_buf_counts {}
foreach {key val} [array get fall_data] {
    lappend fall_delays [lindex $val 0]
    lappend fall_buf_counts [lindex $val 1]
}
set fall_unique [lsort -unique -integer $fall_delays]
set fall_buf_unique [lsort -unique -integer $fall_buf_counts]

puts "\ncascade_delays_fall (FALL transition):"
puts "  Delay range: $fall_unique ps"
puts "  Buffer counts: $fall_buf_unique"
if {[llength $fall_unique] > 1} {
    puts "  ✓ Variable delays achieved"
} else {
    puts "  ⚠ Constant delay"
}

puts "\nDone!\n"