# A/B on LED DRIVE CURRENT ONLY.  The wire bitstream is IDENTICAL in both arms:
# same pattern, same dbg_pat_lvl, same transition density, same CHKSUM structure.
# Only 0x2d/0x3d/0x4d IREF differs -> only the analog LED peak current changes.
# This is the clean version of the dark/bright test, which confounded
# "no LED current" with "all-zero payload = no data transitions".
#   LOW arm better -> LED peak current / ground bounce participates in the failure
#   no difference  -> LED current is out
# args: <name> <gap_hex> [rounds_per_arm] [build_dir] [order LH|HL]
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set N 10
if {[llength $argv] > 2} { set N [lindex $argv 2] }
set BD "build_dbg"
if {[llength $argv] > 3} { set BD [lindex $argv 3] }
set ORDER "LH"
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
set WE 0
proc poke {vn a d} {
    global WE v
    setp $v dbg_reg_addr $a ; setp $v dbg_reg_data $d
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE }
setp $v dbg_frame_gap $GAP
setp $v dbg_pat_mode 0 ; setp $v dbg_pat_lvl 0FFF
set ARMS [expr {$ORDER eq "HL" ? {H L} : {L H}}]
set first [lindex $ARMS 0]
puts "=== IREF A/B on $NAME.  $N rounds per arm.  order=$ORDER"
puts {===   L arm: 2d=2205 3d=2206 4d=2205  (IREF 0.1 mA, peak ~350 mA, HALF brightness)}
puts {===   H arm: 2d=2215 3d=2216 4d=2215  (factory,   peak ~700 mA, full brightness)}
puts {===   Same pattern and same pat_lvl in BOTH arms -- only the LED current differs.}
foreach arm $ARMS {
    if {$arm ne $first} {
        setp $v dbg_pat_mode 5
        puts "=== ---------- SEPARATOR: FULL WHITE 3 s, ARM $arm NEXT ----------"
        after 3000
        setp $v dbg_pat_mode 0
    }
    for {set i 1} {$i <= $N} {incr i} {
        if {$arm eq "L"} { poke $v 2d 2205 ; poke $v 3d 2206 ; poke $v 4d 2205 } \
                    else { poke $v 2d 2215 ; poke $v 3d 2216 ; poke $v 4d 2215 }
        setp $v g_dbg.o_soft_rst 1 ; after 2000
        setp $v g_dbg.o_soft_rst 0 ; after 6000
        puts [format "=== %s  ARM %s  round %2d/%d   COUNT NOW (4 s)" \
            [clock format [clock seconds] -format %T] $arm $i $N]
        after 4000
    }
}
puts "=== done ==="
close_hw_target
exit 0
