# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Delay analysis for MUX3 + BUF cascade
#
# Architecture: N cascaded stages, each = BUFV1 -> I0, direct -> I1, I2.
#   {S1,S0}=00 -> I0 path (through buffer, slowest)
#   {S1,S0}=01 -> I1 path (direct, medium)
#   {S1,S0}=10 -> I2 path (direct, fastest)
#   3 options per stage -> 3^N total configurations.
#
# Method: set_case_analysis on select port pairs to fix
#   each stage to 00, 01, or 10.
# =====================================================

puts "\n=========================================="
puts "Generating Delay Table for MUX3+BUF Cascade"
puts "=========================================="

# Create reports directory
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
}

set num_cascades $design(Nmbr_cascades)

# 3^N total configurations
set total_configs 1
for {set i 0} {$i < $num_cascades} {incr i} {
    set total_configs [expr {$total_configs * 3}]
}

puts "Cascade stages:       $num_cascades"
puts "Total configurations: $total_configs"

# Output files
set table_file "${design(REPORT_DIR)}/delay_table.txt"
set csv_file   "${design(REPORT_DIR)}/delay_table.csv"

set tbl_fh [open $table_file "w"]
set csv_fh [open $csv_file "w"]

# Table header
puts $tbl_fh "===================================================================================="
puts $tbl_fh "  PROGRAMMABLE DELAY LINE - MUX3+BUF CASCADE DELAY TABLE"
puts $tbl_fh "===================================================================================="
puts $tbl_fh "Design:  $design(DESIGN)"
puts $tbl_fh "Stages:  $num_cascades"
puts $tbl_fh "Date:    [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh ""
puts $tbl_fh "Architecture: BUFV1 -> I0, direct -> I1/I2 of MUX3V4_140P9T30R"
puts $tbl_fh "  digit=0 -> {S1,S0}=00 -> I0 (buf, slowest)"
puts $tbl_fh "  digit=1 -> {S1,S0}=01 -> I1 (direct, medium)"
puts $tbl_fh "  digit=2 -> {S1,S0}=10 -> I2 (direct, fastest)"
puts $tbl_fh "===================================================================================="
puts $tbl_fh ""

# CSV header
puts $csv_fh "config,select_${num_cascades}digit,select_bits,rise_ps,fall_ps,speed_sum"

# Get port objects
set in_port  [get_db ports in]
set out_port [get_db ports out]

if {$in_port eq "" || $out_port eq ""} {
    puts "ERROR: Cannot find in/out ports"
    close $tbl_fh
    close $csv_fh
    return
}

# Pre-resolve select port objects
puts "Pre-resolving select port objects..."
set num_select_bits [expr {2 * $num_cascades}]
array set sel_ports {}
for {set i 0} {$i < $num_select_bits} {incr i} {
    set sel_ports($i) [get_db ports "select\[$i\]"]
    if {$sel_ports($i) eq ""} {
        puts "ERROR: Cannot find select\[$i\] port"
    } else {
        puts "  select\[$i\] = $sel_ports($i)"
    }
}

# Verify instances exist
set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set all_bufs  [get_db insts -if {.base_cell.base_name == BUFV1_140P9T30R}]
puts "Found [llength $all_muxes] MUX3 instances"
puts "Found [llength $all_bufs] BUFV1 instances"
puts $tbl_fh "MUX3 instances: [llength $all_muxes]"
puts $tbl_fh "BUFV1 instances: [llength $all_bufs]"
puts $tbl_fh ""

# Table column header
set hdr [format "| %5s | %-${num_cascades}s | %-${num_select_bits}s | %8s | %8s | %5s |" \
    "Cfg" "Trit" "Select\[S1S0\]" "Rise(ps)" "Fall(ps)" "Speed"]
set sep [string repeat "=" [string length $hdr]]

puts $tbl_fh $sep
puts $tbl_fh $hdr
puts $tbl_fh $sep

# Arrays for results
array set rise_delays {}
array set fall_delays {}
array set speed_sums {}

# Helper: extract delay from report file
proc extract_delay_from_file {filepath} {
    set delay 0
    if {![file exists $filepath]} { return 0 }
    set fh [open $filepath r]
    set content [read $fh]
    close $fh
    foreach line [split $content "\n"] {
        if {[regexp {Data Path:-\s+(\d+)} $line match d]} {
            set delay $d
        }
    }
    return $delay
}

# Helper: convert config number to base-3 digits (list of digits, stage 0 first)
proc cfg_to_trits {cfg num_stages} {
    set trits {}
    set val $cfg
    for {set i 0} {$i < $num_stages} {incr i} {
        lappend trits [expr {$val % 3}]
        set val [expr {$val / 3}]
    }
    return $trits
}

# Temp file for report_timing output
set temp_rpt "${design(REPORT_DIR)}/temp_timing.rpt"

# Iterate over all 3^N configurations
for {set cfg 0} {$cfg < $total_configs} {incr cfg} {
    # Get per-stage trit values (0=buf/slow, 1=direct/med, 2=direct/fast)
    set trits [cfg_to_trits $cfg $num_cascades]

    # Build trit string (MSB first for display)
    set trit_str ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        append trit_str [lindex $trits $s]
    }

    # Build select bit pattern (MSB first for display)
    set bit_pattern ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        set t [lindex $trits $s]
        switch $t {
            0 { append bit_pattern "00" }
            1 { append bit_pattern "01" }
            2 { append bit_pattern "10" }
        }
    }

    # Speed sum: sum of trit values (0=slowest, 2=fastest per stage)
    set speed_sum 0
    foreach t $trits { set speed_sum [expr {$speed_sum + $t}] }

    # Apply case analysis
    for {set stage 0} {$stage < $num_cascades} {incr stage} {
        set t [lindex $trits $stage]
        set s0_idx [expr {2 * $stage + 1}]
        set s1_idx [expr {2 * $stage}]
        switch $t {
            0 {
                # {S1,S0}=00 -> I0 (buffer path)
                set_case_analysis 0 $sel_ports($s0_idx)
                set_case_analysis 0 $sel_ports($s1_idx)
            }
            1 {
                # {S1,S0}=01 -> I1 (direct, medium)
                set_case_analysis 1 $sel_ports($s0_idx)
                set_case_analysis 0 $sel_ports($s1_idx)
            }
            2 {
                # {S1,S0}=10 -> I2 (direct, fast)
                set_case_analysis 0 $sel_ports($s0_idx)
                set_case_analysis 1 $sel_ports($s1_idx)
            }
        }
    }

    # Measure rise delay
    set rise_delay 0
    if {[catch {report_timing -from_rise $in_port -to_rise $out_port -unconstrained -path_type full -max_paths 1 > $temp_rpt} err]} {
        puts "WARNING: Rise timing failed for config $cfg: $err"
    } else {
        set rise_delay [extract_delay_from_file $temp_rpt]
    }

    # Measure fall delay
    set fall_delay 0
    if {[catch {report_timing -from_fall $in_port -to_fall $out_port -unconstrained -path_type full -max_paths 1 > $temp_rpt} err]} {
        puts "WARNING: Fall timing failed for config $cfg: $err"
    } else {
        set fall_delay [extract_delay_from_file $temp_rpt]
    }

    # Remove case analysis
    for {set i 0} {$i < $num_select_bits} {incr i} {
        reset_case_analysis $sel_ports($i)
    }

    set rise_delays($cfg) $rise_delay
    set fall_delays($cfg) $fall_delay
    set speed_sums($cfg) $speed_sum

    # Write table row
    puts $tbl_fh [format "| %5d | %-${num_cascades}s | %-${num_select_bits}s | %8d | %8d | %5d |" \
        $cfg $trit_str $bit_pattern $rise_delay $fall_delay $speed_sum]

    # Write CSV row
    puts $csv_fh "$cfg,$trit_str,$bit_pattern,$rise_delay,$fall_delay,$speed_sum"

    if {$cfg % 50 == 0} {
        puts "  Processed $cfg / $total_configs configurations..."
    }
}

# Clean up temp file
file delete -force $temp_rpt

puts "  Processed $total_configs / $total_configs configurations... done."

puts $tbl_fh $sep
puts $tbl_fh ""

# =====================================================
# SELECT_LUT Table (for ODELAYE3 / IDELAYE3)
# =====================================================
# CNT 0 = min delay (all I2), CNT 2*N = max delay (all I0+buf)
# Delay increases with CNT.
# Progression: for each stage (0 up to N-1), switch I2->I1->I0+buf.
#
# SELECT_LUT as list of trit lists {stg0 stg1 ... stgN-1}
#   trit: 0=I0+buf (slowest), 1=I1 (medium), 2=I2 (fastest)

set lut_trits {}

# CNT 0: all I2
set entry {}
for {set i 0} {$i < $num_cascades} {incr i} { lappend entry 2 }
lappend lut_trits $entry

# CNT 1..2*N-1: for each stage 0..N-1, first set to I1, then to I0+buf
for {set stage 0} {$stage < $num_cascades} {incr stage} {
    # Odd CNT: switch stage to I1
    set entry {}
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {$i < $stage} {
            lappend entry 0
        } elseif {$i == $stage} {
            lappend entry 1
        } else {
            lappend entry 2
        }
    }
    lappend lut_trits $entry

    # Even CNT: switch stage to I0+buf
    set entry {}
    for {set i 0} {$i < $num_cascades} {incr i} {
        if {$i <= $stage} {
            lappend entry 0
        } else {
            lappend entry 2
        }
    }
    lappend lut_trits $entry
}

set num_lut [llength $lut_trits]

puts $tbl_fh "===================================================================================="
puts $tbl_fh "  SELECT_LUT TABLE (for ODELAYE3 / IDELAYE3)"
puts $tbl_fh "===================================================================================="
puts $tbl_fh "  CNT 0 = min delay, CNT [expr {$num_lut - 1}] = max delay"
puts $tbl_fh "  Pair encoding (MSB-first): 00=I0+buf, 10=I1, 01=I2"
puts $tbl_fh ""

set num_ports_select [expr {$num_cascades * 2}]
set lut_hdr [format "| %3s | %-${num_select_bits}s | %-[expr {3*$num_cascades}]s | %8s | %8s | %6s | %6s |" \
    "CNT" "select\[$num_ports_select:0\]" "Stages" "Rise(ps)" "Fall(ps)" "dR" "dF"]
set lut_sep [string repeat "=" [string length $lut_hdr]]

puts $tbl_fh $lut_sep
puts $tbl_fh $lut_hdr
puts $tbl_fh $lut_sep

set prev_rise 0
set prev_fall 0

for {set cnt 0} {$cnt < $num_lut} {incr cnt} {
    set trits [lindex $lut_trits $cnt]

    # Compute cfg number: sum(trit[i] * 3^i)
    set cfg_num 0
    set pw3 1
    for {set i 0} {$i < $num_cascades} {incr i} {
        set cfg_num [expr {$cfg_num + [lindex $trits $i] * $pw3}]
        set pw3 [expr {$pw3 * 3}]
    }

    # Build select bit pattern (MSB first: stgN-1 .. stg0)
    set bit_pattern ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        set t [lindex $trits $s]
        switch $t {
            0 { append bit_pattern "00" }
            1 { append bit_pattern "10" }
            2 { append bit_pattern "01" }
        }
    }

    # Build stages description (MSB first: stgN-1 .. stg0)
    set stages_str ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        set t [lindex $trits $s]
        switch $t {
            0 { append stages_str " B " }
            1 { append stages_str " I1" }
            2 { append stages_str " I2" }
        }
    }

    set r $rise_delays($cfg_num)
    set f $fall_delays($cfg_num)

    if {$cnt == 0} {
        set dr_str "   ---"
        set df_str "   ---"
    } else {
        set dr_str [format "%+6d" [expr {$r - $prev_rise}]]
        set df_str [format "%+6d" [expr {$f - $prev_fall}]]
    }

    puts $tbl_fh [format "| %3d | %-${num_select_bits}s | %-[expr {3*$num_cascades}]s | %8d | %8d | %6s | %6s |" \
        $cnt $bit_pattern $stages_str $r $f $dr_str $df_str]

    set prev_rise $r
    set prev_fall $f
}

puts $tbl_fh $lut_sep
puts $tbl_fh ""

# Compute min/max from LUT
set lut_cfg_first 0
set lut_cfg_last 0
set pw3 1
for {set i 0} {$i < $num_cascades} {incr i} {
    set lut_cfg_first [expr {$lut_cfg_first + [lindex [lindex $lut_trits 0] $i] * $pw3}]
    set lut_cfg_last  [expr {$lut_cfg_last  + [lindex [lindex $lut_trits end] $i] * $pw3}]
    set pw3 [expr {$pw3 * 3}]
}
set lut_rise_min $rise_delays($lut_cfg_first)
set lut_rise_max $rise_delays($lut_cfg_last)
set lut_fall_min $fall_delays($lut_cfg_first)
set lut_fall_max $fall_delays($lut_cfg_last)

puts $tbl_fh ""
puts $tbl_fh "Rise range: $lut_rise_min .. $lut_rise_max ps  (total [expr {$lut_rise_max - $lut_rise_min}] ps)"
puts $tbl_fh "Fall range: $lut_fall_min .. $lut_fall_max ps  (total [expr {$lut_fall_max - $lut_fall_min}] ps)"
puts $tbl_fh "Steps: [expr {$num_lut - 1}],  avg step: [format "%.1f" [expr {double($lut_rise_max - $lut_rise_min) / ($num_lut - 1)}]] ps (rise)"
puts $tbl_fh ""
puts $tbl_fh "===================================================================================="
puts $tbl_fh "End of SELECT_LUT Table"
puts $tbl_fh "===================================================================================="

close $tbl_fh
close $csv_fh

puts "\n=========================================="
puts "Delay Table Generation Complete"
puts "=========================================="
puts "Reports:"
puts "  Table: $table_file"
puts "  CSV:   $csv_file"
puts ""
puts "SELECT_LUT: $num_lut entries"
puts "Rise: $lut_rise_min .. $lut_rise_max ps"
puts "Fall: $lut_fall_min .. $lut_fall_max ps"
puts "=========================================="
