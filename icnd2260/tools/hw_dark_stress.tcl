# E3: stress in the DARK, read out in the LIGHT.
# Link traffic during blackout is bit-for-bit identical to normal display
# (same VHEAD / video / CHKSUM / 66x register writes) but LED current is ~0.
# Pattern select is a pure combinational mux on fb_q -- switching it triggers
# NO reconfiguration, so a chip that died in the dark stays dead in the light.
#   9 tiles lit  -> failure REQUIRES LED current (fix is power/decoupling, no fps cost)
#   2..6 tiles   -> LED current is out; back to timing / settle time
# args: <name> <gap_hex> [rounds] [build_dir]
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set N 20
if {[llength $argv] > 2} { set N [lindex $argv 2] }
set BD "build_dbg"
if {[llength $argv] > 3} { set BD [lindex $argv 3] }
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
puts "=== DARK-STRESS $NAME  $N rounds.  Each round:"
puts {===   DARK 6 s: LED current ~0, full link traffic + 66 register writes}
puts {===   then DIM RED 5 s: COUNT how many tiles are clean red (0..9)}
for {set i 1} {$i <= $N} {incr i} {
    setp $v dbg_pat_mode 6 ; setp $v dbg_pat_lvl 0FFF
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 6000
    setp $v dbg_pat_mode 2 ; setp $v dbg_pat_lvl 00FF
    puts [format "=== %s  round %2d/%d   READ NOW (5 s)" \
        [clock format [clock seconds] -format %T] $i $N]
    after 5000
}
puts "=== done ==="
close_hw_target
exit 0
