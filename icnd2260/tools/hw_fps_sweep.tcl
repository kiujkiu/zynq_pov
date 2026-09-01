# Sweep the frame rate live: poke refresh-group count, then walk FRAME_GAP down.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set BD "build_dbg"
set NAME "icnd2260_lvds_dbg_div16"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }
if {[llength $argv] > 1} { set BD   [lindex $argv 1] }
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
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
set WE 0
proc poke {v addr data} {
    global WE
    setp $v dbg_reg_addr $addr ; setp $v dbg_reg_data $data
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE }

# 0x00 = 0x493C -> 0x0F3C : refresh groups 74 -> 16 (manual minimum)
puts "=== poke reg[0x00] = 0x0F3C  (refresh groups 74 -> 16) ==="
poke $v 00 0F3C
setp $v g_dbg.o_soft_rst 1 ; after 300
setp $v g_dbg.o_soft_rst 0 ; after 2000

puts "=== walking FRAME_GAP down.  WATCH THE PANEL - say when it breaks. ==="
foreach g {000001 002F74 00671E 00AAEF 00FFB5 016C6B 01FE44 02C978} {
    setp $v dbg_frame_gap $g
    after 5000
    refresh_hw_vio $v
    puts [format "===   FRAME_GAP=0x%s (%d)   fps=%d   status=0x%s" $g [expr 0x$g] \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}
puts "=== done. left at minimum gap ==="
close_hw_target
exit 0
