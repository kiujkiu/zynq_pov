# Select the runtime test pattern over VIO. ASCII-only (Vivado reads .tcl as GBK).
#   -tclargs <mode> [level_hex]
#   mode: 0=ROM(.mem)  1=RGB cycle  2=red  3=green  4=blue  5=white  6=off
set BD "build_dbg"
set B  ""
set NAME "icnd2260_lvds_dbg_div48"
set MODE 1
set LVL 0FFF
if {[llength $argv] > 0} { set MODE [lindex $argv 0] }
if {[llength $argv] > 1} { set LVL  [lindex $argv 1] }
if {[llength $argv] > 2} { set NAME [lindex $argv 2] }
if {[llength $argv] > 1} { set BD [lindex $argv 1] }
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
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 120  }
setp $v dbg_pat_lvl  $LVL
setp $v dbg_pat_mode $MODE
refresh_hw_vio $v
puts "=== pattern mode=$MODE level=0x$LVL  (0=ROM 1=RGBcycle 2=R 3=G 4=B 5=W 6=off) ==="
puts [format "===   fps=%d  status=0x%s" \
    [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
    [get_property INPUT_VALUE [PX $v g_dbg.status]]]
close_hw_target
exit 0
