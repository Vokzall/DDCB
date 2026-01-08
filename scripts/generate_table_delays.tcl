# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Timing analysis for cascade delay line with 3-input muxes
# Output: delay_analysis.txt (detailed) + delay_simplified.txt (CSV)
# =====================================================

puts "\n=========================================="
puts "Generating Cascade Delay Analysis (3-input MUX)"
puts "=========================================="

if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

set select_pins [get_db ports select*]
set num_select_bits [llength $select_pins]
set num_cascades [expr {$num_select_bits / 2}]

if {$num_cascades == 0} {
    puts "ERROR: Could not detect select pins."
    return
}

puts "Detected $num_cascades cascade stages ($num_select_bits select bits)"

# Output files
set detailed_file "${design(REPORT_DIR)}/delay_analysis.txt"
set simple_file "${design(REPORT_DIR)}/delay_simplified.txt"

set det_fh [open $detailed_file "w"]
set sim_fh [open $simple_file "w"]

# Write detailed header
puts $det_fh "=================================================================================="
puts $det_fh "        PROGRAMMABLE DELAY LINE - CASCADE 3-INPUT MUX ARCHITECTURE"
puts $det_fh "=================================================================================="
puts $det_fh "Design:      $design(DESIGN)"
puts $det_fh "Technology:  $design(TECHNOLOGY)"
puts $det_fh "Stages:      $num_cascades"
puts $det_fh "Date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $det_fh "=================================================================================="
puts $det_fh ""
puts $det_fh "MUX Select Logic (S1,S0): 00=I0(bypass), 01=I1(1buf), 10/11=I2(2buf)"
puts $det_fh ""

# Write simple header (CSV)
puts $sim_fh "SELECT,RISE,FALL"

# Helper procs
proc get_select_pattern {value width} {
    set p ""
    for {set i [expr {$width - 1}]} {$i >= 0} {incr i -1} {
        append p [expr {($value >> $i) & 1}]
    }
    return $p
}

proc decode_mux_input {s1 s0} {
    if {$s1 == 0 && $s0 == 0} {return 0}
    if {$s1 == 0 && $s0 == 1} {return 1}
    return 2
}

proc find_bypass_stage {pattern num_stages} {
    for {set stage 0} {$stage < $num_stages} {incr stage} {
        set bit_pos [expr {($num_stages - 1 - $stage) * 2}]
        set s1 [string index $pattern $bit_pos]
        set s0 [string index $pattern [expr {$bit_pos + 1}]]
        if {$s1 == 0 && $s0 == 0} {
            return $stage
        }
    }
    return -1
}

proc extract_delay {report_text} {
    if {[regexp {Data Path:-\s+(\d+)} $report_text match delay]} {
        return $delay
    }
    return 0
}

# Get ports
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find input/output ports"
    close $det_fh
    close $sim_fh
    return
}

set total_configs [expr {1 << $num_select_bits}]
puts "Analyzing $total_configs configurations...\n"

# Detailed table header
puts $det_fh "| Cfg  | Select Pattern   | Bypass | Rise  | Fall  | Muxes |"
puts $det_fh "|------|------------------|--------|-------|-------|-------|"

# Main loop
for {set config 0} {$config < $total_configs} {incr config} {
    set pattern [get_select_pattern $config $num_select_bits]
    set bypass_stage [find_bypass_stage $pattern $num_cascades]

    # Calculate expected muxes
    if {$bypass_stage != -1} {
        set exp_muxes [expr {$num_cascades - $bypass_stage}]
    } else {
        set exp_muxes $num_cascades
    }

    # Build through pins
    set through_pins {}

    if {$bypass_stage != -1} {
        lappend through_pins "DELAY_STAGES\\\[$bypass_stage\\\].genblk1.mux_inst/I0"
        for {set stage [expr {$bypass_stage + 1}]} {$stage < $num_cascades} {incr stage} {
            set bit_pos [expr {($num_cascades - 1 - $stage) * 2}]
            set s1 [string index $pattern $bit_pos]
            set s0 [string index $pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]
            if {$mux_in == 0} {set mux_in 1}
            lappend through_pins "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst/I$mux_in"
        }
    } else {
        for {set stage 0} {$stage < $num_cascades} {incr stage} {
            set bit_pos [expr {($num_cascades - 1 - $stage) * 2}]
            set s1 [string index $pattern $bit_pos]
            set s0 [string index $pattern [expr {$bit_pos + 1}]]
            set mux_in [decode_mux_input $s1 $s0]
            lappend through_pins "DELAY_STAGES\\\[$stage\\\].genblk1.mux_inst/I$mux_in"
        }
    }

    # Get delays for both transitions
    set rise_dly 0
    set fall_dly 0

    foreach {trans varname} {rise rise_dly fall fall_dly} {
        set tmp_file "${design(REPORT_DIR)}/tmp_timing.rpt"
        set cmd "report_timing -from_${trans} \$in_port -to_${trans} \$out_port"
        foreach pin $through_pins {
            append cmd " -through \[get_db pins $pin\]"
        }
        append cmd " -unconstrained -path_type full -max_paths 1 > $tmp_file"

        if {![catch {eval $cmd}]} {
            if {[file exists $tmp_file]} {
                set f [open $tmp_file r]
                set $varname [extract_delay [read $f]]
                close $f
                file delete $tmp_file
            }
        }
    }

    # Write to detailed file
    set bypass_str [expr {$bypass_stage == -1 ? "none" : $bypass_stage}]
    puts $det_fh [format "| %4d | %16s | %6s | %5d | %5d | %5d |" \
        $config $pattern $bypass_str $rise_dly $fall_dly $exp_muxes]

    # Write to simple file (CSV)
    puts $sim_fh "$pattern,$rise_dly,$fall_dly"

    # Progress
    if {$config % 500 == 0 && $config > 0} {
        puts "Progress: $config / $total_configs ([format %.1f [expr {100.0 * $config / $total_configs}]]%)"
    }
}

puts $det_fh "|------|------------------|--------|-------|-------|-------|"
puts $det_fh ""
puts $det_fh "Done."

close $det_fh
close $sim_fh

puts "\n=========================================="
puts "Analysis Complete"
puts "=========================================="
puts "Detailed: $detailed_file"
puts "Simple:   $simple_file"
puts "==========================================\n"
