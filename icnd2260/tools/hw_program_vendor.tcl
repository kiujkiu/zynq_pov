# Program the vendor-register debug bit and read status once.
# NOTE: keep this file ASCII-only -- Vivado on Windows reads it as GBK and
#       UTF-8 Chinese breaks Tcl quoting (bit us once, cost a run).
# Safety: list every JTAG target first -- we nearly programmed the wrong
#         board before (FS03 is also a Zynq).
set BD "build_dbg"
set B  ""
set NAME "icnd2260_lvds_dbg_div48"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }

if {[llength $argv] > 1} { set BD [lindex $argv 1] }
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
open_hw_manager
connect_hw_server -allow_non_jtag
puts "=== all JTAG targets ==="
foreach t [get_hw_targets] { puts "===   $t" }
set tgts [get_hw_targets */Digilent/*]
if {[llength $tgts] != 1} {
    puts "=== ABORT: found [llength $tgts] Digilent targets, expected 1 ==="
    exit 1
}
current_hw_target [lindex $tgts 0]
open_hw_target
puts "=== devices on target: [get_hw_devices] ==="
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]

set_property PROGRAM.FILE      "$B/$NAME.bit" $dev
set_property PROBES.FILE       "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE  "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
puts "=== programmed $NAME (vendor register table) ==="
after 3000

set v [lindex [get_hw_vios] 0]
proc P {v pat} {
    foreach p [get_hw_probes -of_objects $v] {
        if {[string match $pat [get_property NAME $p]]} { return $p }
    }
    return ""
}
refresh_hw_vio $v
set st  [get_property INPUT_VALUE [P $v "*status*"]]
set fps [get_property INPUT_VALUE [P $v "*fps_latched*"]]
set fc  [get_property INPUT_VALUE [P $v "*frame_cnt*"]]
puts "=== status=0x$st  fps=[expr 0x$fps]  frame_cnt=0x$fc ==="
set s [expr 0x$st]
puts [format "===   mmcm_locked=%d running=%d out_en=%d en_3v8=%d en_2v8=%d ack_ok_sticky=%d" \
      [expr ($s>>15)&1] [expr ($s>>14)&1] [expr ($s>>13)&1] [expr ($s>>12)&1] [expr ($s>>11)&1] [expr ($s>>10)&1]]
after 2000
refresh_hw_vio $v
puts "=== after 2s frame_cnt=0x[get_property INPUT_VALUE [P $v "*frame_cnt*"]] (should be rising) ==="
close_hw_target
exit 0
