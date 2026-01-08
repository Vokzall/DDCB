# Simplified delay analysis - minimal output for AI processing
# Output format: SELECT_PATTERN,RISE_DELAY,FALL_DELAY

puts "Generating simplified delay table..."

if {![file exists $design(REPORT_DIR)]} {
    file mkdir $design(REPORT_DIR)
}

set select_pins [get_db ports select*]
set num_select_bits [llength $select_pins]
set num_cascades [expr {$num_select_bits / 2}]

if {$num_cascades == 0} {
    puts "ERROR: No select pins found"
    return
}

set total_configs [expr {1 << $num_select_bits}]
puts "Stages: $num_cascades, Configs: $total_configs"

set out_file "${design(REPORT_DIR)}/delay_analysis.txt"
set fh [open $out_file "w"]

puts $fh "SELECT,RISE,FALL"

set in_port [get_db ports in]
set out_port [get_db ports out]

proc get_select_pattern {value width} {
    set p ""
    for {set i [expr {$width - 1}]} {$i >= 0} {incr i -1} {
        append p [expr {($value >> $i) & 1}]
    }
    return $p
}

proc decode_mux {s1 s0} {
    if {$s1 == 0 && $s0 == 0} {return 0}
    if {$s1 == 0 && $s0 == 1} {return 1}
    return 2
}

proc find_bypass {pattern n} {
    for {set s 0} {$s < $n} {incr s} {
        set pos [expr {($n - 1 - $s) * 2}]
        if {[string index $pattern $pos] == 0 && [string index $pattern [expr {$pos + 1}]] == 0} {
            return $s
        }
    }
    return -1
}

proc get_delay {report} {
    if {[regexp {Data Path:-\s+(\d+)} $report m d]} {return $d}
    return 0
}

for {set cfg 0} {$cfg < $total_configs} {incr cfg} {
    set pat [get_select_pattern $cfg $num_select_bits]
    set bypass [find_bypass $pat $num_cascades]

    set through {}

    if {$bypass != -1} {
        lappend through "DELAY_STAGES\\\[$bypass\\\].genblk1.mux_inst/I0"
        for {set s [expr {$bypass + 1}]} {$s < $num_cascades} {incr s} {
            set pos [expr {($num_cascades - 1 - $s) * 2}]
            set mux_in [decode_mux [string index $pat $pos] [string index $pat [expr {$pos + 1}]]]
            if {$mux_in == 0} {set mux_in 1}
            lappend through "DELAY_STAGES\\\[$s\\\].genblk1.mux_inst/I$mux_in"
        }
    } else {
        for {set s 0} {$s < $num_cascades} {incr s} {
            set pos [expr {($num_cascades - 1 - $s) * 2}]
            set mux_in [decode_mux [string index $pat $pos] [string index $pat [expr {$pos + 1}]]]
            lappend through "DELAY_STAGES\\\[$s\\\].genblk1.mux_inst/I$mux_in"
        }
    }

    set rise_dly 0
    set fall_dly 0

    foreach {trans var} {rise rise_dly fall fall_dly} {
        set tmp "${design(REPORT_DIR)}/tmp_${cfg}_${trans}.rpt"
        set cmd "report_timing -from_${trans} \$in_port -to_${trans} \$out_port"
        foreach pin $through {
            append cmd " -through \[get_db pins $pin\]"
        }
        append cmd " -unconstrained -path_type full -max_paths 1 > $tmp"

        if {![catch {eval $cmd}]} {
            if {[file exists $tmp]} {
                set f [open $tmp r]
                set $var [get_delay [read $f]]
                close $f
                file delete $tmp
            }
        }
    }

    puts $fh "$pat,$rise_dly,$fall_dly"

    if {$cfg % 1000 == 0} {
        puts "Progress: $cfg / $total_configs"
    }
}

close $fh
puts "Done: $out_file"
