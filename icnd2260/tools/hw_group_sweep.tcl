# Sweep ONLY reg 0x00[14:8] (refresh group count).  Everything else untouched.
# Each poke fully overwrites 0x00, so the state stays well defined.
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
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
set WE 0
setp $v dbg_frame_gap $GAP
after 2000
puts "=== refresh-group sweep, fps fixed, ONLY reg 0x00 changes. WATCH THE PANEL. ==="
set step 0
foreach {val grp cap} {3F3C 64 208  3B3C 60 222  373C 56 238  333C 52 256  2F3C 48 278} {
    incr step
    setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $val
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 2500
    after 9000
    refresh_hw_vio $v
    puts [format "===   STEP %d/5  groups=%-3s  chip cap=%s fps   measured fps=%d  status=0x%s" \
        $step $grp $cap [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}
puts "=== done. left at 16 groups ==="
close_hw_target
exit 0
