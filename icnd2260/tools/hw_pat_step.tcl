# Step through solid colours manually, then hand over to auto-cycle.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
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
set pm [PX $v dbg_pat_mode]
set pl [PX $v dbg_pat_lvl]
set_property OUTPUT_VALUE 0FFF $pl ; commit_hw_vio $pl
foreach {m tag} {6 OFF 2 RED 3 GREEN 4 BLUE 5 WHITE 0 ROM-checkerboard 1 AUTO-CYCLE} {
    set_property OUTPUT_VALUE $m $pm ; commit_hw_vio $pm
    refresh_hw_vio $v
    puts [format "===  mode=%s (%s)   readback=%s   fps=%d  frame_cnt=0x%s" \
        $m $tag [get_property OUTPUT_VALUE $pm] \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v frame_cnt]]]
    after 3000
}
puts "=== left in AUTO-CYCLE (mode 1) ==="
close_hw_target
exit 0
