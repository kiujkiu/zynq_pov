# Single-chip frame-rate ceiling sweep.
# For each refresh-group setting (reg 0x00 [15:8] = groups-1) we set FRAME_GAP so the
# sent frame rate sits just under the chip's predicted display capability, then hold.
# The operator judges: (a) is the image intact  (b) how many grey steps are still distinct.
# args: <name> <build_dir> [hold_seconds]
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set BD   [lindex $argv 1]
set HOLD 15
if {[llength $argv] > 2} { set HOLD [lindex $argv 2] }
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
# {groups reg00 gap_dec expected_fps}
set PTS {
    {74 493C 332570 180}
    {32 1F3C 135588 416}
    {16 0F3C  60378 833}
    { 8 073C  22863 1666}
    { 4 033C   4105 3332}
    { 2 013C      0 4265}
    { 1 003C      0 4265}
}
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
setp $v dbg_pat_mode 0 ; setp $v dbg_pat_lvl 0FFF
puts "=== SINGLE-CHIP FPS SWEEP on $NAME.  $HOLD s per point."
puts {===   At each point judge: (a) image INTACT?  (b) how many grey steps still distinct?}
foreach pt $PTS {
    lassign $pt grp r00 gapd exp
    setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $r00
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    setp $v dbg_frame_gap [format %06X $gapd]
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 3000
    refresh_hw_vio $v
    set got [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]
    puts [format "=== %s  groups=%2d  reg00=0x%s  gap=%d  predicted=%d  MEASURED_SENT=%d fps   LOOK NOW (%d s)" \
        [clock format [clock seconds] -format %T] $grp $r00 $gapd $exp $got $HOLD]
    after [expr {$HOLD*1000}]
}
puts "=== done ==="
close_hw_target
exit 0
