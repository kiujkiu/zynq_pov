# Establish an unambiguous known-good baseline: fresh program, one frame-gap
# setting, NO register pokes at all, then leave it there.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
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
set p [PX $v dbg_frame_gap]
set_property OUTPUT_VALUE $GAP $p ; commit_hw_vio $p
after 3000
refresh_hw_vio $v
puts [format "===  BASELINE: %s  gap=0x%s  fps=%d  status=0x%s  (no register pokes)" \
    $NAME $GAP [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
    [get_property INPUT_VALUE [PX $v g_dbg.status]]]
close_hw_target
exit 0
