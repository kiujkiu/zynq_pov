# Hold ONE setting for a long time and sample periodically.
# Is the failure a hard threshold, or intermittent?
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set REG  [lindex $argv 2]
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
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
setp $v dbg_frame_gap $GAP
setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $REG
setp $v g_dbg.o_we_tog 1
setp $v g_dbg.o_soft_rst 1 ; after 300
setp $v g_dbg.o_soft_rst 0 ; after 3000
puts "=== HOLD: reg\[0x00\]=0x$REG, gap=0x$GAP.  60 s.  WATCH FOR FLICKER / CHANGE. ==="
for {set i 1} {$i <= 12} {incr i} {
    after 5000
    refresh_hw_vio $v
    puts [format "===   t=%2ds  fps=%d  frame_cnt=0x%s  status=0x%s" [expr 5*$i] \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v frame_cnt]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}
close_hw_target
exit 0
