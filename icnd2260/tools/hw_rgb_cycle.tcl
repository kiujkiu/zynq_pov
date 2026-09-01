# Part A: let the RTL auto-cycle run.  Part B: host-driven R/G/B cycle.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div32"
set LVL 0800
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }
if {[llength $argv] > 1} { set LVL  [lindex $argv 1] }
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
refresh_hw_device $dev
set v ""
for {set t 0} {$t < 5} {incr t} {
    set vs [get_hw_vios]
    if {[llength $vs] > 0} { set v [lindex $vs 0] ; break }
    after 1000 ; refresh_hw_device $dev }
if {$v eq ""} { puts "=== ABORT: no VIO ===" ; exit 1 }
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 120 }
setp $v dbg_pat_lvl $LVL

puts "=== PART A: RTL auto-cycle (mode 1), 12 s. Colour should change on its own. ==="
setp $v dbg_pat_mode 1
for {set i 0} {$i < 6} {incr i} {
    after 2000 ; refresh_hw_vio $v
    puts [format "===   A t=%2ds  fps=%d" [expr 2*($i+1)] \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]]
}
puts "=== PART B: host-driven R -> G -> B, 3 rounds, 2 s each ==="
foreach round {1 2 3} {
    foreach {m tag} {2 RED 3 GREEN 4 BLUE} {
        setp $v dbg_pat_mode $m
        puts "===   B round $round : $tag"
        after 2000
    }
}
setp $v dbg_pat_mode 1
puts "=== left in RTL auto-cycle (mode 1) ==="
close_hw_target
exit 0
