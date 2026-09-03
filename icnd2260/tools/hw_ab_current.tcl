# A/B: does LED current during power-up participate in the failure?
#   A rounds: stress in the DARK (pat_mode=6, LED ~0), then read BRIGHT
#   B rounds: stress BRIGHT (pat_mode=0),              then read BRIGHT
# Readout conditions are IDENTICAL in both arms, so readout-induced damage
# cancels out. Only the stress condition differs.
# Separator between arms: full WHITE for 3 s.
# args: <name> <gap_hex> [rounds_per_arm] [build_dir]
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set N 10
if {[llength $argv] > 2} { set N [lindex $argv 2] }
set BD "build_dbg"
if {[llength $argv] > 3} { set BD [lindex $argv 3] }
# 5th arg: arm order. "AB" (default) or "BA" -- run reversed to rule out time/thermal drift.
set ORDER "AB"
if {[llength $argv] > 4} { set ORDER [lindex $argv 4] }
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROGRAM.FILE     "$B/$NAME.bit" $dev
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
after 2000
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
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
setp $v dbg_frame_gap $GAP
setp $v dbg_pat_lvl 0FFF
puts "=== A/B CURRENT TEST on $NAME.  $N rounds per arm."
puts {===   ARM A: dark during power-up, then bright colour legend 4 s <- count}
puts {===   3 s FULL WHITE = separator}
puts {===   ARM B: bright during power-up, then same bright legend 4 s <- count}
set ARMS [expr {$ORDER eq "BA" ? {B A} : {A B}}]
set first [lindex $ARMS 0]
foreach arm $ARMS {
    if {$arm ne $first} {
        setp $v dbg_pat_mode 5
        puts "=== ---------- SEPARATOR: FULL WHITE 3 s, ARM $arm NEXT ----------"
        after 3000
    }
    for {set i 1} {$i <= $N} {incr i} {
        setp $v dbg_pat_mode [expr {$arm eq "A" ? 6 : 0}]
        setp $v g_dbg.o_soft_rst 1 ; after 2000
        setp $v g_dbg.o_soft_rst 0 ; after 6000
        setp $v dbg_pat_mode 0
        puts [format "=== %s  ARM %s  round %2d/%d   COUNT NOW (4 s)" \
            [clock format [clock seconds] -format %T] $arm $i $N]
        after 4000
    }
}
puts "=== done ==="
close_hw_target
exit 0
