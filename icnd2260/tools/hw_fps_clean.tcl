# Clean frame-rate sweep: NO register pokes at all, vendor table as loaded.
# Boundary hypothesis: our frame period must be >= the chip's display frame time.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
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
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
puts "=== CLEAN sweep: no register pokes.  Predicted chip ceiling at 62.5MHz = 180 fps ==="
foreach {g tag} {046041 150fps 03CC6C 165fps 035132 180fps 02E8AB 195fps 028F17 210fps 01FE44 240fps} {
    setp $v dbg_frame_gap $g
    after 5000
    refresh_hw_vio $v
    puts [format "===   target=%s  gap=0x%s  measured fps=%d  status=0x%s" $tag $g \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}
close_hw_target
exit 0
