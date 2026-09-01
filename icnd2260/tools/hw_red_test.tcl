# Isolate the "red channel weakens" effect: same clock, same fps, ONLY refresh
# groups change.  Fresh program first so no stale pokes survive.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set GAP [lindex $argv 1]
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
proc rd {v} { refresh_hw_vio $v
    return [format "fps=%d status=0x%s" \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]] }

setp $v dbg_frame_gap $GAP
after 8000
puts "===  A0  vendor table, 74 refresh groups, NO pokes    [rd $v]   <-- BASELINE, 8s"
after 8000
# poke ONLY 0x00: refresh groups 74 -> 16 (0x493C -> 0x0F3C, low byte untouched)
setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data 0F3C ; setp $v g_dbg.o_we_tog 1
setp $v g_dbg.o_soft_rst 1 ; after 300
setp $v g_dbg.o_soft_rst 0 ; after 3000
puts "===  A1  ONLY reg\[0x00\] 74 -> 16 groups             [rd $v]   <-- 8s"
after 8000
puts "=== done. left at A1 (16 groups) ==="
close_hw_target
exit 0
