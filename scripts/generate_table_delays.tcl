# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Linear delay analysis for programmable delay line
#          with 3-input MUX and DEL1V4_140P9T30R delay cells
# Sweeps 0..3*Nmbr_cascades delay elements, filling stages LSB to MSB
# Per stage: I2=0 DEL, I1=1 DEL, I0=3 DEL (del1 shared between I1 and I0)
# =====================================================

puts "\n=========================================="
puts "Generating Linear Delay Analysis (DEL1V4 + MUX3)"
puts "=========================================="

# Create reports directory
if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
    puts "Created reports directory: $design(REPORT_DIR)"
}

# Auto-detect number of cascades
set select_pins [get_db ports select*]
set num_select_bits [llength $select_pins]

if {$num_select_bits == 0} {
    puts "ERROR: Could not detect select pins."
    return
}

set num_cascades [expr {$num_select_bits / 2}]
set max_delays 31 ;# 32 steps (0..31), matches SELECT_LUT size
set total_steps [expr {$max_delays + 1}]

puts "Cascades: $num_cascades"
puts "Max delay elements: $max_delays"
puts "Total steps: $total_steps (0..$max_delays)"

# Verify ports and instances
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find in/out ports"
    return
}

set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set all_dels  [get_db insts -if {.base_cell.base_name == DEL1V4_140P9T30R}]
puts "Found [llength $all_muxes] MUX3 instances, [llength $all_dels] DEL1V4 instances"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

set tbl_fh [open $table_file "w"]
set det_fh [open $detailed_file "w"]

# Header
puts $tbl_fh "=================================================================================="
puts $tbl_fh "     PROGRAMMABLE DELAY LINE - LINEAR SWEEP ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:         $design(DESIGN)"
puts $tbl_fh "Technology:     $design(TECHNOLOGY)"
puts $tbl_fh "Stages:         $num_cascades"
puts $tbl_fh "Max DEL1V4:     $max_delays"
puts $tbl_fh "Steps:          $total_steps (0..$max_delays delay elements)"
puts $tbl_fh "Date:           [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "Architecture per stage:"
puts $tbl_fh "  I0 - 3x DEL1V4_140P9T30R (3 DEL1V4) : S1=0, S0=0 -> select=00"
puts $tbl_fh "  I1 - 1x DEL1V4_140P9T30R (1 DEL1V4) : S1=0, S0=1 -> select=01"
puts $tbl_fh "  I2 - Direct wire         (0 DEL1V4) : S1=1, S0=0 -> select=10"
puts $tbl_fh "  (del1 is shared between I1 and I0 paths)"
puts $tbl_fh ""
puts $tbl_fh "Sweep: fill stages from LSB (stage 0) to MSB (stage [expr {$num_cascades-1}])"
puts $tbl_fh "  Step N: N/3 full stages (I0) + N%3 partial stages (I1) + rest (I2)"
puts $tbl_fh ""

# =====================================================
# Build through-pin list for a given step
# =====================================================
# For step N:
#   full_stages = N / 3  -> these go through I0 (3 DEL each)
#   partial     = N % 3  -> 0, 1, or 2 next stages go through I1 (1 DEL each)
#   rest                 -> go through I2 (direct wire)
proc build_through_pins {step num_cascades} {
    set full_stages [expr {$step / 3}]
    set partial     [expr {$step % 3}]

    set through_list {}
    set config_desc ""

    for {set s 0} {$s < $num_cascades} {incr s} {
        set mux_path "DELAY_STAGES\\\[$s\\\].genblk_mux.mux_inst"

        if {$s < $full_stages} {
            # I0: 3 delay elements (select=00)
            lappend through_list "${mux_path}/I0"
            append config_desc "S${s}:I0 "
        } elseif {$s < $full_stages + $partial} {
            # I1: 1 delay element (select=01)
            lappend through_list "${mux_path}/I1"
            append config_desc "S${s}:I1 "
        } else {
            # I2: direct wire (select=10)
            lappend through_list "${mux_path}/I2"
            append config_desc "S${s}:I2 "
        }
    }

    return [list $through_list $config_desc $full_stages $partial]
}

# =====================================================
# Extract total delay from timing report
# =====================================================
proc extract_delay {report_text} {
    set total_delay "N/A"
    set del_count 0
    set del_delay 0
    set mux_count 0
    set mux_delay 0

    set lines [split $report_text "\n"]

    foreach line $lines {
        # Total path delay
        if {[regexp {Data Path:-\s+(\d+)} $line match delay]} {
            set total_delay $delay
        }
        # DEL1V4 cells
        if {[regexp {DEL1V4_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr del_count
            set del_delay [expr {$del_delay + $delay}]
        }
        # MUX3 cells
        if {[regexp {MUX3V4_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr mux_count
            set mux_delay [expr {$mux_delay + $delay}]
        }
    }

    return [list $total_delay $del_count $del_delay $mux_count $mux_delay]
}

# =====================================================
# Main analysis loop
# =====================================================
array set rise_data {}
array set fall_data {}
array set step_info {}

for {set step 0} {$step <= $max_delays} {incr step} {
    lassign [build_through_pins $step $num_cascades] through_list config_desc cnt_i0 cnt_i1

    set cnt_i2 [expr {$num_cascades - $cnt_i0 - $cnt_i1}]
    set expected_dels $step
    set step_info($step) [list $config_desc $expected_dels $cnt_i0 $cnt_i1 $cnt_i2]

    puts "Step $step/$max_delays: DEL1V4=$expected_dels | $config_desc"

    foreach transition {rise fall} {
        if {$transition == "rise"} {
            set from_opt "-from_rise"
            set to_opt "-to_rise"
        } else {
            set from_opt "-from_fall"
            set to_opt "-to_fall"
        }

        set report_file "${design(REPORT_DIR)}/temp_timing_${step}_${transition}.rpt"

        set cmd "report_timing $from_opt \$in_port $to_opt \$out_port"
        foreach pin $through_list {
            append cmd " -through \[get_db pins $pin\]"
        }
        append cmd " -unconstrained -path_type full -max_paths 1 > $report_file"

        if {[catch {eval $cmd} err]} {
            puts "  WARNING ($transition): $err"
            puts $det_fh "\n== Step $step | $transition | FAILED: $err =="
            set ${transition}_data($step) [list 0 0 0 0 0]
            continue
        }

        if {[file exists $report_file]} {
            set fh [open $report_file "r"]
            set content [read $fh]
            close $fh

            puts $det_fh "\n=========================================="
            puts $det_fh "Step: $step | DEL1V4: $expected_dels | $transition"
            puts $det_fh "Config: $config_desc"
            puts $det_fh "=========================================="
            puts $det_fh $content

            set ${transition}_data($step) [extract_delay $content]
            file delete $report_file
        } else {
            set ${transition}_data($step) [list 0 0 0 0 0]
        }
    }
}

# =====================================================
# Results table
# =====================================================
foreach transition {rise fall} {
    set tr_upper [string toupper $transition]
    puts $tbl_fh "${tr_upper} TRANSITION ANALYSIS"
    puts $tbl_fh "=============================================================================================="
    puts $tbl_fh "| Step | DEL1V4 | Total   | DEL1V4 in path | MUX in path    | Other   | Match |"
    puts $tbl_fh "|      | Expect | Delay   | Cnt  | Delay   | Cnt  | Delay   | Delay   |       |"
    puts $tbl_fh "|      |        | (ps)    |      | (ps)    |      | (ps)    | (ps)    |       |"
    puts $tbl_fh "=============================================================================================="

    for {set step 0} {$step <= $max_delays} {incr step} {
        lassign $step_info($step) config_desc expected_dels
        lassign [set ${transition}_data($step)] total del_cnt del_dly mux_cnt mux_dly

        if {$total == "N/A" || $total == 0} {
            set other "N/A"
            set match "---"
        } else {
            set other [expr {$total - $del_dly - $mux_dly}]
            set match [expr {$del_cnt == $expected_dels ? "YES" : "NO"}]
        }

        puts $tbl_fh [format "| %4d | %6d | %7s | %4s | %7s | %4s | %7s | %7s | %5s |" \
            $step $expected_dels $total $del_cnt $del_dly $mux_cnt $mux_dly $other $match]
    }

    puts $tbl_fh "=============================================================================================="
    puts $tbl_fh ""
}

# =====================================================
# Summary analysis
# =====================================================
puts $tbl_fh "=================================================================================="
puts $tbl_fh "                              DELAY SUMMARY"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""

foreach transition {rise fall} {
    set delays {}
    for {set step 0} {$step <= $max_delays} {incr step} {
        set d [lindex [set ${transition}_data($step)] 0]
        if {$d != "N/A" && $d > 0} {
            lappend delays $d
        }
    }

    set tr_upper [string toupper $transition]

    if {[llength $delays] == 0} {
        puts $tbl_fh "${tr_upper}: No valid paths found"
        continue
    }

    set sorted [lsort -integer $delays]
    set dmin [lindex $sorted 0]
    set dmax [lindex $sorted end]
    set range [expr {$dmax - $dmin}]
    set unique [lsort -unique -integer $delays]

    puts $tbl_fh "${tr_upper} Transition:"
    puts $tbl_fh "  Valid measurements: [llength $delays] / $total_steps"
    puts $tbl_fh "  Unique delays:     [llength $unique]"
    puts $tbl_fh "  Min delay:         $dmin ps"
    puts $tbl_fh "  Max delay:         $dmax ps"
    puts $tbl_fh "  Range:             $range ps"

    # Calculate step sizes between consecutive measurements
    if {[llength $delays] > 1} {
        set steps_list {}
        for {set i 1} {$i < [llength $delays]} {incr i} {
            set delta [expr {[lindex $delays $i] - [lindex $delays [expr {$i-1}]]}]
            lappend steps_list $delta
        }

        set step_min [lindex [lsort -integer $steps_list] 0]
        set step_max [lindex [lsort -integer $steps_list] end]

        # Average step
        set sum 0
        foreach s $steps_list { set sum [expr {$sum + $s}] }
        set step_avg [expr {double($sum) / [llength $steps_list]}]

        puts $tbl_fh "  Step min:          $step_min ps"
        puts $tbl_fh "  Step max:          $step_max ps"
        puts $tbl_fh [format "  Step avg:          %.1f ps" $step_avg]

        if {$range > 0} {
            set lsb_ps [format "%.2f" [expr {double($range) / $max_delays}]]
            puts $tbl_fh "  LSB (range/$max_delays): $lsb_ps ps"
        }
    }
    puts $tbl_fh ""
}

# =====================================================
# Summary table: step, select pattern, rise, fall, |rise-fall|, I0/I1/I2 counts
# =====================================================
puts $tbl_fh "=================================================================================="
puts $tbl_fh "                          COMBINED SUMMARY TABLE"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh [format "| %4s | %-*s | %7s | %7s | %7s | %3s | %3s | %3s |" \
    "Step" [expr {$num_cascades * 2}] "Select" "Rise" "Fall" "|R-F|" "I0" "I1" "I2"]
puts $tbl_fh [format "| %4s | %-*s | %7s | %7s | %7s | %3s | %3s | %3s |" \
    "" [expr {$num_cascades * 2}] "" "(ps)" "(ps)" "(ps)" "" "" ""]
puts $tbl_fh [string repeat "=" [expr {56 + $num_cascades * 2}]]

for {set step 0} {$step <= $max_delays} {incr step} {
    lassign $step_info($step) config_desc expected_dels cnt_i0 cnt_i1 cnt_i2

    # Build select pattern: 2 bits per stage, MSB(stage N-1) ... LSB(stage 0)
    # I0: S1S0=00 (3 DEL), I1: S1S0=01 (1 DEL), I2: S1S0=10 (0 DEL)
    set select_pattern ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        if {$s < $cnt_i0} {
            append select_pattern "00"
        } elseif {$s < $cnt_i0 + $cnt_i1} {
            append select_pattern "01"
        } else {
            append select_pattern "10"
        }
    }

    set rise_d [lindex $rise_data($step) 0]
    set fall_d [lindex $fall_data($step) 0]

    if {$rise_d != "N/A" && $rise_d > 0 && $fall_d != "N/A" && $fall_d > 0} {
        set diff [expr {abs($rise_d - $fall_d)}]
    } else {
        set diff "N/A"
    }

    puts $tbl_fh [format "| %4d | %s | %7s | %7s | %7s | %3s | %3s | %3s |" \
        $step $select_pattern $rise_d $fall_d $diff $cnt_i0 $cnt_i1 $cnt_i2]
}

puts $tbl_fh [string repeat "=" [expr {56 + $num_cascades * 2}]]
puts $tbl_fh ""
puts $tbl_fh "Select pattern: MSB (stage [expr {$num_cascades-1}]) ... LSB (stage 0)"
puts $tbl_fh "  00 = I0 (3 DEL), 01 = I1 (1 DEL), 10 = I2 (direct)"
puts $tbl_fh ""

puts $tbl_fh "=================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=================================================================================="

close $tbl_fh
close $det_fh

# Console summary
puts "\n=========================================="
puts "Delay Analysis Complete"
puts "=========================================="
puts "Reports:"
puts "  Table:    $table_file"
puts "  Detailed: $detailed_file"
puts "=========================================="

set rise_delays {}
set fall_delays {}
for {set step 0} {$step <= $max_delays} {incr step} {
    set rd [lindex $rise_data($step) 0]
    set fd [lindex $fall_data($step) 0]
    if {$rd != "N/A" && $rd > 0} { lappend rise_delays $rd }
    if {$fd != "N/A" && $fd > 0} { lappend fall_delays $fd }
}

if {[llength $rise_delays] > 1} {
    set rmin [lindex [lsort -integer $rise_delays] 0]
    set rmax [lindex [lsort -integer $rise_delays] end]
    puts "\nRise: ${rmin}..${rmax} ps (range: [expr {$rmax - $rmin}] ps, [llength $rise_delays] valid steps)"
} else {
    puts "\nRise: insufficient data"
}

if {[llength $fall_delays] > 1} {
    set fmin [lindex [lsort -integer $fall_delays] 0]
    set fmax [lindex [lsort -integer $fall_delays] end]
    puts "Fall: ${fmin}..${fmax} ps (range: [expr {$fmax - $fmin}] ps, [llength $fall_delays] valid steps)"
} else {
    puts "Fall: insufficient data"
}

puts "\nDone!\n"
