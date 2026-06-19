# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Multi-corner delay analysis for programmable delay line
#          with 3-input MUX and DEL2V0_140P9T30R delay cells
#
# Phase 1: Measure ALL (a,b) configs at 3 corners (slow/typ/fast)
# Phase 2: Select 32 uniformly-spaced steps (based on typical avg)
# Phase 3: Output tables with all corners + SELECT_LUT
#
# Per stage: I2=0 DEL (direct), I1=1 DEL, I0=3 DEL
#            (del1 is shared between I1 and I0 paths)
# =====================================================

puts "\n=========================================="
puts "Generating Multi-Corner Delay Analysis"
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
set max_del_total [expr {$num_cascades * 3}]
set num_lut_steps 32

# Corner views: {label view_name}
set corners $design(CORNERS)

puts "Cascades:          $num_cascades"
puts "Max DEL elements:  $max_del_total"
puts "Target LUT steps:  $num_lut_steps"
puts "Corners:           [llength $corners]"
foreach c $corners {
    puts "  [lindex $c 0] -> [lindex $c 1]"
}

# Verify ports and instances
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find in/out ports"
    return
}

set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set all_dels  [get_db insts -if {.base_cell.base_name == DEL2V0_140P9T30R}]
puts "Found [llength $all_muxes] MUX3 instances, [llength $all_dels] DEL2V0 instances"

# =====================================================
# Build through-pin list for a given (a, b) pair
# =====================================================
proc build_through_pins_ab {a b num_cascades} {
    set through_list {}
    set config_desc ""

    for {set s 0} {$s < $num_cascades} {incr s} {
        set mux_path "DELAY_STAGES\\\[$s\\\].genblk_mux.mux_inst"

        if {$s < $a} {
            lappend through_list "${mux_path}/I0"
            append config_desc "S${s}:I0 "
        } elseif {$s < $a + $b} {
            lappend through_list "${mux_path}/I1"
            append config_desc "S${s}:I1 "
        } else {
            lappend through_list "${mux_path}/I2"
            append config_desc "S${s}:I2 "
        }
    }

    set cnt_i2 [expr {$num_cascades - $a - $b}]
    return [list $through_list $config_desc $a $b $cnt_i2]
}

# =====================================================
# Build select pattern string (MSB..LSB)
# =====================================================
proc build_select_pattern {cnt_i0 cnt_i1 num_cascades} {
    set pattern ""
    for {set s [expr {$num_cascades - 1}]} {$s >= 0} {incr s -1} {
        if {$s < $cnt_i0} {
            append pattern "00"
        } elseif {$s < $cnt_i0 + $cnt_i1} {
            append pattern "01"
        } else {
            append pattern "10"
        }
    }
    return $pattern
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
        if {[regexp {Data Path:-\s+(\d+)} $line match delay]} {
            set total_delay $delay
        }
        if {[regexp {DEL2V0_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr del_count
            set del_delay [expr {$del_delay + $delay}]
        }
        if {[regexp {MUX3V4_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
            incr mux_count
            set mux_delay [expr {$mux_delay + $delay}]
        }
    }

    return [list $total_delay $del_count $del_delay $mux_count $mux_delay]
}

# =====================================================
# PHASE 1: Measure ALL (a, b) configurations at ALL corners
# =====================================================
puts "\n--- Phase 1: Measuring all (a, b) configurations at [llength $corners] corners ---"

set all_configs {}
for {set a 0} {$a <= $num_cascades} {incr a} {
    for {set b 0} {$b <= $num_cascades - $a} {incr b} {
        set del_total [expr {3 * $a + $b}]
        lappend all_configs [list $a $b $del_total]
    }
}

set num_configs [llength $all_configs]
puts "Total configurations: $num_configs x [llength $corners] corners = [expr {$num_configs * [llength $corners]}] measurements"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

set det_fh [open $detailed_file "w"]

# Data storage: cfg_data(key,corner,transition) = [list total del_cnt del_dly mux_cnt mux_dly]
array set cfg_data {}
array set cfg_info {}

set cfg_idx 0
foreach cfg $all_configs {
    lassign $cfg a b del_total
    set key "${a}_${b}"

    lassign [build_through_pins_ab $a $b $num_cascades] through_list config_desc cnt_i0 cnt_i1 cnt_i2
    set cfg_info($key) [list $config_desc $del_total $a $b $cnt_i2]

    incr cfg_idx
    puts "Config $cfg_idx/$num_configs: a=$a b=$b DEL=$del_total"

    foreach corner $corners {
        lassign $corner clabel cview

        foreach transition {rise fall} {
            if {$transition == "rise"} {
                set from_opt "-from_rise"
                set to_opt "-to_rise"
            } else {
                set from_opt "-from_fall"
                set to_opt "-to_fall"
            }

            set report_file "${design(REPORT_DIR)}/temp_timing_${key}_${clabel}_${transition}.rpt"

            set cmd "report_timing $from_opt \$in_port $to_opt \$out_port -view $cview"
            foreach pin $through_list {
                append cmd " -through \[get_db pins $pin\]"
            }
            append cmd " -unconstrained -path_type full -max_paths 1 > $report_file"

            if {[catch {eval $cmd} err]} {
                puts "  WARNING ($clabel/$transition): $err"
                puts $det_fh "\n== a=$a b=$b | $clabel | $transition | FAILED: $err =="
                set cfg_data($key,$clabel,$transition) [list 0 0 0 0 0]
                continue
            }

            if {[file exists $report_file]} {
                set fh [open $report_file "r"]
                set content [read $fh]
                close $fh

                puts $det_fh "\n=========================================="
                puts $det_fh "a=$a b=$b DEL=$del_total | $clabel | $transition"
                puts $det_fh "=========================================="
                puts $det_fh $content

                set cfg_data($key,$clabel,$transition) [extract_delay $content]
                file delete $report_file
            } else {
                set cfg_data($key,$clabel,$transition) [list 0 0 0 0 0]
            }
        }
    }
}

close $det_fh

# =====================================================
# PHASE 2: Select 32 uniformly-spaced steps
#          (based on TYPICAL corner average)
# =====================================================
puts "\n--- Phase 2: Selecting $num_lut_steps uniform steps (based on typ corner) ---"

# measured list: {key a b del_total typ_rise typ_fall typ_avg}
set measured {}
foreach cfg $all_configs {
    lassign $cfg a b del_total
    set key "${a}_${b}"

    set rise_d [lindex $cfg_data($key,typ,rise) 0]
    set fall_d [lindex $cfg_data($key,typ,fall) 0]

    if {$rise_d == "N/A" || $rise_d == 0 || $fall_d == "N/A" || $fall_d == 0} {
        puts "  WARNING: a=$a b=$b DEL=$del_total has no valid typ timing, skipping"
        continue
    }

    set avg [expr {($rise_d + $fall_d) / 2.0}]
    lappend measured [list $key $a $b $del_total $rise_d $fall_d $avg]
}

# Sort by typ avg ascending (index 6)
set measured [lsort -real -index 6 $measured]

puts "Valid measured configs: [llength $measured]"

if {[llength $measured] < $num_lut_steps} {
    puts "WARNING: Only [llength $measured] valid configs, need $num_lut_steps"
}

set min_avg [lindex [lindex $measured 0] 6]
set max_avg [lindex [lindex $measured end] 6]
set ideal_step [expr {($max_avg - $min_avg) / ($num_lut_steps - 1.0)}]

puts "Min typ avg: $min_avg ps"
puts "Max typ avg: $max_avg ps"
puts [format "Ideal step:  %.2f ps" $ideal_step]

# Greedy drop: remove configs that worsen uniformity least
set candidates $measured
set num_to_drop [expr {[llength $candidates] - $num_lut_steps}]

puts "Configs to drop: $num_to_drop"

proc uniformity_cost {configs} {
    set n [llength $configs]
    if {$n < 2} { return 1e18 }
    set min_a [lindex [lindex $configs 0] 6]
    set max_a [lindex [lindex $configs end] 6]
    set ideal_s [expr {($max_a - $min_a) / ($n - 1.0)}]
    set cost 0.0
    for {set i 1} {$i < $n} {incr i} {
        set actual [expr {[lindex [lindex $configs $i] 6] - [lindex [lindex $configs [expr {$i-1}]] 6]}]
        set dev [expr {$actual - $ideal_s}]
        set cost [expr {$cost + $dev * $dev}]
    }
    return $cost
}

for {set drop 0} {$drop < $num_to_drop} {incr drop} {
    set best_cost 1e18
    set best_drop_idx -1

    for {set j 1} {$j < [llength $candidates] - 1} {incr j} {
        set trial [lreplace $candidates $j $j]
        set cost [uniformity_cost $trial]
        if {$cost < $best_cost} {
            set best_cost $cost
            set best_drop_idx $j
        }
    }

    set dropped [lindex $candidates $best_drop_idx]
    puts [format "  Drop a=%d b=%d DEL=%2d (typ_avg=%.0f ps) -> cost=%.1f" \
        [lindex $dropped 1] [lindex $dropped 2] [lindex $dropped 3] [lindex $dropped 6] $best_cost]
    set candidates [lreplace $candidates $best_drop_idx $best_drop_idx]
}

# Build selected list with all corner data
# selected: {lut_idx key a b del_total}
set selected {}
set sel_min [lindex [lindex $candidates 0] 6]
set sel_max [lindex [lindex $candidates end] 6]
set ideal_step_sel [expr {($sel_max - $sel_min) / ($num_lut_steps - 1.0)}]

for {set i 0} {$i < $num_lut_steps} {incr i} {
    set entry [lindex $candidates $i]
    set ideal [expr {$sel_min + $i * $ideal_step_sel}]
    set err [expr {abs([lindex $entry 6] - $ideal)}]
    lappend selected [list $i [lindex $entry 0] [lindex $entry 1] [lindex $entry 2] [lindex $entry 3]]
    puts [format "  LUT\[%2d\]: a=%d b=%d DEL=%2d  typ_avg=%.0f ps  ideal=%.0f ps  err=%.1f ps" \
        $i [lindex $entry 1] [lindex $entry 2] [lindex $entry 3] [lindex $entry 6] $ideal $err]
}

set ideal_step $ideal_step_sel

# =====================================================
# PHASE 3: Output tables with all corners
# =====================================================
puts "\n--- Phase 3: Writing reports ---"

set tbl_fh [open $table_file "w"]
set sel_width [expr {$num_cascades * 2}]

# Header
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "     PROGRAMMABLE DELAY LINE - MULTI-CORNER UNIFORM STEP ANALYSIS"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "Design:         $design(DESIGN)"
puts $tbl_fh "Technology:     $design(TECHNOLOGY)"
puts $tbl_fh "Stages:         $num_cascades"
puts $tbl_fh "Max DEL total:  $max_del_total"
puts $tbl_fh "Measured:       $num_configs configs x [llength $corners] corners"
puts $tbl_fh "LUT steps:      $num_lut_steps"
puts $tbl_fh [format "Ideal step:     %.2f ps (typ corner)" $ideal_step]
puts $tbl_fh "Corners:"
foreach c $corners {
    puts $tbl_fh "  [lindex $c 0] -> [lindex $c 1]"
}
puts $tbl_fh "Date:           [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh ""
puts $tbl_fh "Architecture per stage:"
puts $tbl_fh "  I0 - 3x DEL2V0_140P9T30R (3 DEL) : select=00"
puts $tbl_fh "  I1 - 1x DEL2V0_140P9T30R (1 DEL) : select=01"
puts $tbl_fh "  I2 - Direct wire         (0 DEL) : select=10"
puts $tbl_fh "  (del1 is shared between I1 and I0 paths)"
puts $tbl_fh ""

# =====================================================
# Selected 32 steps — multi-corner table
# =====================================================
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "                     SELECTED $num_lut_steps UNIFORM STEPS — ALL CORNERS"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh ""

# Header line
set hdr [format "| %4s | %3s | %3s | %3s |" "Step" "I0" "I1" "DEL"]
foreach c $corners {
    set cl [lindex $c 0]
    append hdr [format " %5s_R | %5s_F |" $cl $cl]
}
append hdr [format " %7s |" "typ_avg"]
puts $tbl_fh $hdr

set hdr2 [format "| %4s | %3s | %3s | %3s |" "" "" "" ""]
foreach c $corners {
    append hdr2 [format " %7s | %7s |" "(ps)" "(ps)"]
}
append hdr2 [format " %7s |" "(ps)"]
puts $tbl_fh $hdr2

set line_w [string length $hdr]
puts $tbl_fh [string repeat "=" $line_w]

foreach entry $selected {
    lassign $entry lut_idx key a b del_total

    if {$key == ""} {
        set line [format "| %4d | %3s | %3s | %3s |" $lut_idx "---" "---" "---"]
        foreach c $corners {
            append line [format " %7s | %7s |" "---" "---"]
        }
        append line [format " %7s |" "---"]
        puts $tbl_fh $line
        continue
    }

    set line [format "| %4d | %3d | %3d | %3d |" $lut_idx $a $b $del_total]

    set typ_r [lindex $cfg_data($key,typ,rise) 0]
    set typ_f [lindex $cfg_data($key,typ,fall) 0]
    if {$typ_r != "N/A" && $typ_r > 0 && $typ_f != "N/A" && $typ_f > 0} {
        set typ_avg [format "%.0f" [expr {($typ_r + $typ_f) / 2.0}]]
    } else {
        set typ_avg "N/A"
    }

    foreach c $corners {
        set cl [lindex $c 0]
        set r [lindex $cfg_data($key,$cl,rise) 0]
        set f [lindex $cfg_data($key,$cl,fall) 0]
        append line [format " %7s | %7s |" $r $f]
    }
    append line [format " %7s |" $typ_avg]

    puts $tbl_fh $line
}

puts $tbl_fh [string repeat "=" $line_w]
puts $tbl_fh ""

# =====================================================
# Select patterns + SELECT_LUT
# =====================================================
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "                     SELECT PATTERNS"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh ""
puts $tbl_fh [format "| %4s | %-*s | %3s | %3s | %3s |" "Step" $sel_width "Select" "I0" "I1" "I2"]
puts $tbl_fh [string repeat "=" [expr {20 + $sel_width}]]

foreach entry $selected {
    lassign $entry lut_idx key a b del_total
    if {$key == ""} { continue }
    set cnt_i2 [expr {$num_cascades - $a - $b}]
    set pat [build_select_pattern $a $b $num_cascades]
    puts $tbl_fh [format "| %4d | %s | %3d | %3d | %3d |" $lut_idx $pat $a $b $cnt_i2]
}
puts $tbl_fh [string repeat "=" [expr {20 + $sel_width}]]
puts $tbl_fh ""
puts $tbl_fh "Select pattern: MSB (stage [expr {$num_cascades-1}]) ... LSB (stage 0)"
puts $tbl_fh "  00 = I0 (3 DEL), 01 = I1 (1 DEL), 10 = I2 (direct)"
puts $tbl_fh ""

# =====================================================
# SELECT_LUT generation
# =====================================================
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "                     SELECT_LUT (for RTL)"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh ""
puts $tbl_fh "localparam logic \[${sel_width}-1:0\] SELECT_LUT \[0:31\] = '{"

set lut_lines {}
foreach entry $selected {
    lassign $entry lut_idx key a b del_total

    if {$key == ""} {
        lappend lut_lines [format "    ${sel_width}'b%s" [string repeat "1" $sel_width]]
        continue
    }

    set cnt_i2 [expr {$num_cascades - $a - $b}]
    set pat [build_select_pattern $a $b $num_cascades]
    set comment [format "// step %2d: DEL=%2d (a=%d,b=%d)" $lut_idx $del_total $a $b]

    if {$lut_idx < $num_lut_steps - 1} {
        lappend lut_lines [format "    ${sel_width}'b%s,  %s" $pat $comment]
    } else {
        lappend lut_lines [format "    ${sel_width}'b%s   %s" $pat $comment]
    }
}

foreach line $lut_lines {
    puts $tbl_fh $line
}
puts $tbl_fh "};"
puts $tbl_fh ""

# =====================================================
# Summary per corner
# =====================================================
puts $tbl_fh "=================================================================================================="
puts $tbl_fh "                              DELAY SUMMARY PER CORNER"
puts $tbl_fh "=================================================================================================="
puts $tbl_fh ""

foreach c $corners {
    set cl [lindex $c 0]
    set cl_upper [string toupper $cl]

    set rises {}
    set falls {}
    foreach entry $selected {
        lassign $entry lut_idx key a b del_total
        if {$key == ""} { continue }
        set r [lindex $cfg_data($key,$cl,rise) 0]
        set f [lindex $cfg_data($key,$cl,fall) 0]
        if {$r != "N/A" && $r > 0} { lappend rises $r }
        if {$f != "N/A" && $f > 0} { lappend falls $f }
    }

    puts $tbl_fh "Corner: $cl_upper"
    puts $tbl_fh [string repeat "-" 50]

    foreach {label delays} [list "RISE" $rises "FALL" $falls] {
        if {[llength $delays] < 2} {
            puts $tbl_fh "  ${label}: insufficient data"
            continue
        }

        set sorted [lsort -integer $delays]
        set dmin [lindex $sorted 0]
        set dmax [lindex $sorted end]
        set range [expr {$dmax - $dmin}]

        set steps_list {}
        for {set i 1} {$i < [llength $delays]} {incr i} {
            set delta [expr {[lindex $delays $i] - [lindex $delays [expr {$i-1}]]}]
            lappend steps_list $delta
        }

        set step_min [lindex [lsort -integer $steps_list] 0]
        set step_max [lindex [lsort -integer $steps_list] end]
        set sum 0
        foreach s $steps_list { set sum [expr {$sum + $s}] }
        set step_avg [expr {double($sum) / [llength $steps_list]}]
        set lsb_ps [format "%.2f" [expr {double($range) / ($num_lut_steps - 1)}]]

        puts $tbl_fh [format "  %s: %d..%d ps  range=%d ps  step=%.1f ps  LSB=%s ps" \
            $label $dmin $dmax $range $step_avg $lsb_ps]
    }

    # Rise-Fall mismatch stats
    set rf_diffs {}
    foreach entry $selected {
        lassign $entry lut_idx key a b del_total
        if {$key == ""} { continue }
        set r [lindex $cfg_data($key,$cl,rise) 0]
        set f [lindex $cfg_data($key,$cl,fall) 0]
        if {$r != "N/A" && $r > 0 && $f != "N/A" && $f > 0} {
            lappend rf_diffs [expr {abs($r - $f)}]
        }
    }
    if {[llength $rf_diffs] > 0} {
        set sorted_rf [lsort -integer $rf_diffs]
        set sum_rf 0
        foreach d $rf_diffs { set sum_rf [expr {$sum_rf + $d}] }
        set avg_rf [expr {double($sum_rf) / [llength $rf_diffs]}]
        puts $tbl_fh [format "  |R-F|: avg=%.1f ps  max=%d ps" $avg_rf [lindex $sorted_rf end]]
    }
    puts $tbl_fh ""
}

puts $tbl_fh "=================================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=================================================================================================="

close $tbl_fh

# Console summary
puts "\n=========================================="
puts "Multi-Corner Delay Analysis Complete"
puts "=========================================="
puts "Reports:"
puts "  Table:    $table_file"
puts "  Detailed: $detailed_file"

foreach c $corners {
    set cl [lindex $c 0]
    set rises {}
    set falls {}
    foreach entry $selected {
        lassign $entry lut_idx key a b del_total
        if {$key == ""} { continue }
        set r [lindex $cfg_data($key,$cl,rise) 0]
        set f [lindex $cfg_data($key,$cl,fall) 0]
        if {$r != "N/A" && $r > 0} { lappend rises $r }
        if {$f != "N/A" && $f > 0} { lappend falls $f }
    }
    if {[llength $rises] > 1} {
        set rmin [lindex [lsort -integer $rises] 0]
        set rmax [lindex [lsort -integer $rises] end]
        set fmin [lindex [lsort -integer $falls] 0]
        set fmax [lindex [lsort -integer $falls] end]
        puts "\n[string toupper $cl]: Rise ${rmin}..${rmax} ps  Fall ${fmin}..${fmax} ps"
    }
}

puts "\nDone!\n"
