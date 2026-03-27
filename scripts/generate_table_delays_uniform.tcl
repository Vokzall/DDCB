# =====================================================
# Script: generate_table_delays.tcl
# Purpose: Delay analysis for programmable delay line
#          with 3-input MUX and CLKBUFV24RQ_140P9T30R delay cells
#
# Phase 1: Measure ALL (a,b) configs: a*I0 + b*I1, a+b<=N  -> (N+1)(N+2)/2 total
# Phase 2: Select 32 uniformly-spaced steps from measured data
# Phase 3: Output tables + SELECT_LUT
#
# Per stage: I2=0 DEL (direct), I1=1 DEL, I0=3 DEL
#            (del1 is shared between I1 and I0 paths)
# =====================================================

puts "\n=========================================="
puts "Generating Delay Analysis (DEL1V4 + MUX3)"
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

puts "Cascades:          $num_cascades"
puts "Max DEL elements:  $max_del_total"
puts "Target LUT steps:  $num_lut_steps"

# Verify ports and instances
set in_port [get_db ports in]
set out_port [get_db ports out]

if {[llength $in_port] == 0 || [llength $out_port] == 0} {
    puts "ERROR: Could not find in/out ports"
    return
}

set all_muxes [get_db insts -if {.base_cell.base_name == MUX3V4_140P9T30R}]
set all_dels  [get_db insts -if {.base_cell.base_name == CLKBUFV24RQ_140P9T30R}]
puts "Found [llength $all_muxes] MUX3 instances, [llength $all_dels] DEL1V4 instances"

# =====================================================
# Build through-pin list for a given (a, b) pair
# a = number of I0 stages (3 DEL each)
# b = number of I1 stages (1 DEL each)
# rest = I2 stages (0 DEL, direct wire)
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
    # I0: S1S0=00 (3 DEL), I1: S1S0=01 (1 DEL), I2: S1S0=10 (0 DEL)
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
        if {[regexp {CLKBUFV24RQ_140P9T30R\s+\d+\s+[\d.]+\s+\d+\s+(\d+)\s+\d+} $line match delay]} {
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
# PHASE 1: Measure ALL (a, b) configurations
# a = I0 stages (3 DEL), b = I1 stages (1 DEL), a+b <= N
# Total configs = sum(N-a+1, a=0..N) = (N+1)*(N+2)/2
# =====================================================
puts "\n--- Phase 1: Measuring all (a, b) configurations ---"

set all_configs {}
for {set a 0} {$a <= $num_cascades} {incr a} {
    for {set b 0} {$b <= $num_cascades - $a} {incr b} {
        set del_total [expr {3 * $a + $b}]
        lappend all_configs [list $a $b $del_total]
    }
}

set num_configs [llength $all_configs]
puts "Total configurations: $num_configs (a,b pairs where a+b <= $num_cascades)"

# Output files
set table_file "${design(REPORT_DIR)}/delay_analysis.txt"
set detailed_file "${design(REPORT_DIR)}/timing_paths_detailed.rpt"

set det_fh [open $detailed_file "w"]

# Measure each (a, b) config
# Key: "a_b" string
array set cfg_rise_data {}
array set cfg_fall_data {}
array set cfg_info {}

set cfg_idx 0
foreach cfg $all_configs {
    lassign $cfg a b del_total
    set key "${a}_${b}"

    lassign [build_through_pins_ab $a $b $num_cascades] through_list config_desc cnt_i0 cnt_i1 cnt_i2
    set cfg_info($key) [list $config_desc $del_total $a $b $cnt_i2]

    incr cfg_idx
    puts "Config $cfg_idx/$num_configs: a=$a b=$b DEL=$del_total | $config_desc"

    foreach transition {rise fall} {
        if {$transition == "rise"} {
            set from_opt "-from_rise"
            set to_opt "-to_rise"
        } else {
            set from_opt "-from_fall"
            set to_opt "-to_fall"
        }

        set report_file "${design(REPORT_DIR)}/temp_timing_${key}_${transition}.rpt"

        set cmd "report_timing $from_opt \$in_port $to_opt \$out_port"
        foreach pin $through_list {
            append cmd " -through \[get_db pins $pin\]"
        }
        append cmd " -unconstrained -path_type full -max_paths 1 > $report_file"

        if {[catch {eval $cmd} err]} {
            puts "  WARNING ($transition): $err"
            puts $det_fh "\n== a=$a b=$b DEL=$del_total | $transition | FAILED: $err =="
            set cfg_${transition}_data($key) [list 0 0 0 0 0]
            continue
        }

        if {[file exists $report_file]} {
            set fh [open $report_file "r"]
            set content [read $fh]
            close $fh

            puts $det_fh "\n=========================================="
            puts $det_fh "a=$a b=$b DEL=$del_total | $transition"
            puts $det_fh "Config: $config_desc"
            puts $det_fh "=========================================="
            puts $det_fh $content

            set cfg_${transition}_data($key) [extract_delay $content]
            file delete $report_file
        } else {
            set cfg_${transition}_data($key) [list 0 0 0 0 0]
        }
    }
}

close $det_fh

# =====================================================
# PHASE 2: Select 32 uniformly-spaced steps
# =====================================================
puts "\n--- Phase 2: Selecting $num_lut_steps uniform steps ---"

# Compute average delay for each (a, b) config
# measured list: {key a b del_total rise fall avg}
set measured {}
foreach cfg $all_configs {
    lassign $cfg a b del_total
    set key "${a}_${b}"

    set rise_d [lindex $cfg_rise_data($key) 0]
    set fall_d [lindex $cfg_fall_data($key) 0]

    if {$rise_d == "N/A" || $rise_d == 0 || $fall_d == "N/A" || $fall_d == 0} {
        puts "  WARNING: a=$a b=$b DEL=$del_total has no valid timing, skipping"
        continue
    }

    set avg [expr {($rise_d + $fall_d) / 2.0}]
    lappend measured [list $key $a $b $del_total $rise_d $fall_d $avg]
}

# Sort by avg delay ascending (avg is index 6)
set measured [lsort -real -index 6 $measured]

puts "Valid measured configs: [llength $measured]"

if {[llength $measured] < $num_lut_steps} {
    puts "WARNING: Only [llength $measured] valid configs, need $num_lut_steps"
}

# Get min/max
set min_avg [lindex [lindex $measured 0] 6]
set max_avg [lindex [lindex $measured end] 6]
set ideal_step [expr {($max_avg - $min_avg) / ($num_lut_steps - 1.0)}]

puts "Min avg delay: $min_avg ps"
puts "Max avg delay: $max_avg ps"
puts [format "Ideal step:    %.2f ps" $ideal_step]

# Selection: pick best 32 from N available, maximizing uniformity
# Strategy: try all combinations of (N - 32) configs to drop,
# but N-32 is small (4 for 36 configs), so use greedy drop instead:
# repeatedly drop the config whose removal least worsens uniformity.

# Start with all measured configs (sorted by avg ascending)
set candidates $measured
set num_to_drop [expr {[llength $candidates] - $num_lut_steps}]

puts "Configs to drop: $num_to_drop"

# Uniformity cost: sum of squared deviations from ideal step (avg at index 6)
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

    # Don't drop first or last (preserve min/max range)
    for {set j 1} {$j < [llength $candidates] - 1} {incr j} {
        set trial [lreplace $candidates $j $j]
        set cost [uniformity_cost $trial]
        if {$cost < $best_cost} {
            set best_cost $cost
            set best_drop_idx $j
        }
    }

    set dropped [lindex $candidates $best_drop_idx]
    puts [format "  Drop a=%d b=%d DEL=%2d (avg=%.0f ps) -> cost=%.1f" \
        [lindex $dropped 1] [lindex $dropped 2] [lindex $dropped 3] [lindex $dropped 6] $best_cost]
    set candidates [lreplace $candidates $best_drop_idx $best_drop_idx]
}

# candidates now has exactly 32 entries, sorted by avg ascending
# Assign LUT indices 0..31 and compute error vs ideal
# selected list: {lut_idx key a b del_total rise fall avg ideal err}
set selected {}
set sel_min [lindex [lindex $candidates 0] 6]
set sel_max [lindex [lindex $candidates end] 6]
set ideal_step_sel [expr {($sel_max - $sel_min) / ($num_lut_steps - 1.0)}]

for {set i 0} {$i < $num_lut_steps} {incr i} {
    set entry [lindex $candidates $i]
    set ideal [expr {$sel_min + $i * $ideal_step_sel}]
    set err [expr {abs([lindex $entry 6] - $ideal)}]
    # {lut_idx key a b del_total rise fall avg ideal err}
    lappend selected [list $i [lindex $entry 0] [lindex $entry 1] [lindex $entry 2] \
        [lindex $entry 3] [lindex $entry 4] [lindex $entry 5] [lindex $entry 6] $ideal $err]
    puts [format "  LUT\[%2d\]: a=%d b=%d DEL=%2d  avg=%.0f ps  ideal=%.0f ps  err=%.1f ps" \
        $i [lindex $entry 1] [lindex $entry 2] [lindex $entry 3] [lindex $entry 6] $ideal $err]
}

# Recalculate ideal_step for report header
set ideal_step $ideal_step_sel

# =====================================================
# PHASE 3: Output tables
# =====================================================
puts "\n--- Phase 3: Writing reports ---"

set tbl_fh [open $table_file "w"]

# Header
puts $tbl_fh "=================================================================================="
puts $tbl_fh "     PROGRAMMABLE DELAY LINE - UNIFORM STEP ANALYSIS"
puts $tbl_fh "=================================================================================="
puts $tbl_fh "Design:         $design(DESIGN)"
puts $tbl_fh "Technology:     $design(TECHNOLOGY)"
puts $tbl_fh "Stages:         $num_cascades"
puts $tbl_fh "Max DEL total:  $max_del_total"
puts $tbl_fh "Measured:       $num_configs configs (all a,b pairs)"
puts $tbl_fh "LUT steps:      $num_lut_steps"
puts $tbl_fh [format "Ideal step:     %.2f ps" $ideal_step]
puts $tbl_fh "Date:           [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $tbl_fh "=================================================================================="
puts $tbl_fh ""
puts $tbl_fh "Architecture per stage:"
puts $tbl_fh "  I0 - 3x CLKBUFV24RQ_140P9T30R (3 DEL1V4) : select=00"
puts $tbl_fh "  I1 - 1x CLKBUFV24RQ_140P9T30R (1 DEL1V4) : select=01"
puts $tbl_fh "  I2 - Direct wire         (0 DEL1V4) : select=10"
puts $tbl_fh "  (del1 is shared between I1 and I0 paths)"
puts $tbl_fh ""

# =====================================================
# Full measurement table (all a,b configs, sorted by avg)
# =====================================================
puts $tbl_fh "===================================================================================="
puts $tbl_fh "                     ALL CONFIGURATIONS (sorted by avg delay)"
puts $tbl_fh "===================================================================================="
puts $tbl_fh ""
puts $tbl_fh [format "| %3s | %3s | %3s | %7s | %7s | %7s | %7s | %3s |" \
    "I0" "I1" "DEL" "Rise" "Fall" "Avg" "|R-F|" "I2"]
puts $tbl_fh [format "| %3s | %3s | %3s | %7s | %7s | %7s | %7s | %3s |" \
    "(a)" "(b)" "" "(ps)" "(ps)" "(ps)" "(ps)" ""]
puts $tbl_fh [string repeat "=" 68]

# Use already-sorted measured list
foreach entry $measured {
    lassign $entry key a b del_total rise_d fall_d avg
    set cnt_i2 [expr {$num_cascades - $a - $b}]

    set diff [expr {abs($rise_d - $fall_d)}]

    puts $tbl_fh [format "| %3d | %3d | %3d | %7s | %7s | %7.0f | %7d | %3d |" \
        $a $b $del_total $rise_d $fall_d $avg $diff $cnt_i2]
}
puts $tbl_fh [string repeat "=" 68]
puts $tbl_fh ""

# =====================================================
# Selected 32 steps table
# =====================================================
set sel_width [expr {$num_cascades * 2}]

puts $tbl_fh "===================================================================================="
puts $tbl_fh "                     SELECTED $num_lut_steps UNIFORM STEPS"
puts $tbl_fh "===================================================================================="
puts $tbl_fh ""
puts $tbl_fh [format "| %4s | %3s | %-*s | %7s | %7s | %7s | %7s | %7s | %3s | %3s | %3s |" \
    "Step" "DEL" $sel_width "Select" "Rise" "Fall" "Avg" "|R-F|" "Error" "I0" "I1" "I2"]
puts $tbl_fh [format "| %4s | %3s | %-*s | %7s | %7s | %7s | %7s | %7s | %3s | %3s | %3s |" \
    "" "" $sel_width "" "(ps)" "(ps)" "(ps)" "(ps)" "(ps)" "" "" ""]
puts $tbl_fh [string repeat "=" [expr {72 + $sel_width}]]

foreach entry $selected {
    # {lut_idx key a b del_total rise fall avg ideal err}
    lassign $entry lut_idx key a b del_total rise_d fall_d avg ideal err

    if {$key == ""} {
        puts $tbl_fh [format "| %4d | %3s | %-*s | %7s | %7s | %7s | %7s | %7s | %3s | %3s | %3s |" \
            $lut_idx "---" $sel_width "---" "---" "---" "---" "---" "---" "---" "---" "---"]
        continue
    }

    set cnt_i2 [expr {$num_cascades - $a - $b}]
    set select_pattern [build_select_pattern $a $b $num_cascades]

    set diff [expr {abs($rise_d - $fall_d)}]

    puts $tbl_fh [format "| %4d | %3d | %s | %7s | %7s | %7.0f | %7d | %7.1f | %3d | %3d | %3d |" \
        $lut_idx $del_total $select_pattern $rise_d $fall_d $avg $diff $err $a $b $cnt_i2]
}

puts $tbl_fh [string repeat "=" [expr {72 + $sel_width}]]
puts $tbl_fh ""
puts $tbl_fh "Select pattern: MSB (stage [expr {$num_cascades-1}]) ... LSB (stage 0)"
puts $tbl_fh "  00 = I0 (3 DEL), 01 = I1 (1 DEL), 10 = I2 (direct)"
puts $tbl_fh ""

# =====================================================
# SELECT_LUT generation (for IDELAYE3/ODELAYE3)
# =====================================================
puts $tbl_fh "===================================================================================="
puts $tbl_fh "                     SELECT_LUT (for RTL)"
puts $tbl_fh "===================================================================================="
puts $tbl_fh ""
puts $tbl_fh "localparam logic \[${sel_width}-1:0\] SELECT_LUT \[0:31\] = '{"

set lut_lines {}
foreach entry $selected {
    # {lut_idx key a b del_total rise fall avg ideal err}
    lassign $entry lut_idx key a b del_total rise_d fall_d avg ideal err

    if {$key == ""} {
        lappend lut_lines [format "    ${sel_width}'b%s" [string repeat "1" $sel_width]]
        continue
    }

    set cnt_i2 [expr {$num_cascades - $a - $b}]
    set select_pattern [build_select_pattern $a $b $num_cascades]

    set comment [format "// step %2d: DEL=%2d (a=%d,b=%d), I0=%d I1=%d I2=%d" $lut_idx $del_total $a $b $a $b $cnt_i2]

    if {$lut_idx < $num_lut_steps - 1} {
        lappend lut_lines [format "    ${sel_width}'b%s,  %s" $select_pattern $comment]
    } else {
        lappend lut_lines [format "    ${sel_width}'b%s   %s" $select_pattern $comment]
    }
}

foreach line $lut_lines {
    puts $tbl_fh $line
}
puts $tbl_fh "};"
puts $tbl_fh ""

# =====================================================
# Summary
# =====================================================
puts $tbl_fh "===================================================================================="
puts $tbl_fh "                              DELAY SUMMARY"
puts $tbl_fh "===================================================================================="
puts $tbl_fh ""

set sel_rises {}
set sel_falls {}
foreach entry $selected {
    # {lut_idx key a b del_total rise fall avg ideal err}
    lassign $entry lut_idx key a b del_total rise_d fall_d avg ideal err
    if {$key != "" && $rise_d > 0} { lappend sel_rises $rise_d }
    if {$key != "" && $fall_d > 0} { lappend sel_falls $fall_d }
}

foreach {label delays} [list "RISE" $sel_rises "FALL" $sel_falls] {
    if {[llength $delays] < 2} {
        puts $tbl_fh "${label}: insufficient data"
        continue
    }

    set sorted [lsort -integer $delays]
    set dmin [lindex $sorted 0]
    set dmax [lindex $sorted end]
    set range [expr {$dmax - $dmin}]
    set unique [lsort -unique -integer $delays]

    puts $tbl_fh "${label} Transition (selected $num_lut_steps steps):"
    puts $tbl_fh "  Valid:       [llength $delays] / $num_lut_steps"
    puts $tbl_fh "  Unique:      [llength $unique]"
    puts $tbl_fh "  Min delay:   $dmin ps"
    puts $tbl_fh "  Max delay:   $dmax ps"
    puts $tbl_fh "  Range:       $range ps"

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

    puts $tbl_fh "  Step min:    $step_min ps"
    puts $tbl_fh "  Step max:    $step_max ps"
    puts $tbl_fh [format "  Step avg:    %.1f ps" $step_avg]

    if {$range > 0} {
        set lsb_ps [format "%.2f" [expr {double($range) / ($num_lut_steps - 1)}]]
        puts $tbl_fh "  LSB (range/31): $lsb_ps ps"
    }
    puts $tbl_fh ""
}

# Uniformity metric
set err_sum 0
set err_max 0
foreach entry $selected {
    lassign $entry lut_idx key a b del_total rise_d fall_d avg ideal err
    if {$key != ""} {
        set err_sum [expr {$err_sum + $err}]
        if {$err > $err_max} { set err_max $err }
    }
}
set err_avg [expr {$err_sum / $num_lut_steps}]
puts $tbl_fh [format "Uniformity:  avg_error=%.1f ps  max_error=%.1f ps" $err_avg $err_max]
puts $tbl_fh ""

puts $tbl_fh "=================================================================================="
puts $tbl_fh "End of Analysis"
puts $tbl_fh "=================================================================================="

close $tbl_fh

# Console summary
puts "\n=========================================="
puts "Delay Analysis Complete"
puts "=========================================="
puts "Reports:"
puts "  Table:    $table_file"
puts "  Detailed: $detailed_file"

if {[llength $sel_rises] > 1} {
    set rmin [lindex [lsort -integer $sel_rises] 0]
    set rmax [lindex [lsort -integer $sel_rises] end]
    puts "\nRise: ${rmin}..${rmax} ps (range: [expr {$rmax - $rmin}] ps)"
}
if {[llength $sel_falls] > 1} {
    set fmin [lindex [lsort -integer $sel_falls] 0]
    set fmax [lindex [lsort -integer $sel_falls] end]
    puts "Fall: ${fmin}..${fmax} ps (range: [expr {$fmax - $fmin}] ps)"
}

puts "\nDone!\n"
