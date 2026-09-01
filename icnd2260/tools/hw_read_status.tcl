# Read VIO telemetry from an already-programmed board. Does NOT reprogram.
# ASCII-only on purpose (Vivado/Windows reads .tcl as GBK).
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }

open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
refresh_hw_device $dev

set v [lindex [get_hw_vios] 0]
puts "=== every probe on the VIO ==="
foreach p [get_hw_probes -of_objects $v] {
    puts "===   [get_property NAME $p]  w=[get_property WIDTH $p]"
}

proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*_$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best
}
set p_fps  [PX $v "fps_latched"]
set p_fc   [PX $v "frame_cnt"]
set p_st   [PX $v "status"]
set p_acnt [PX $v "ack_frame_cnt"]
set p_aerr [PX $v "ack_err_cnt"]
puts "=== bound: fps=[get_property NAME $p_fps] frame_cnt=[get_property NAME $p_fc] ack_cnt=[get_property NAME $p_acnt] ==="

puts "=== 6 samples, 1s apart ==="
for {set i 0} {$i < 6} {incr i} {
    refresh_hw_vio $v
    puts [format "===  t=%ds  fps=%-6d frame_cnt=%-10d status=0x%s ack_cnt=%d ack_err=%d" \
        $i [expr 0x[get_property INPUT_VALUE $p_fps]] \
        [expr 0x[get_property INPUT_VALUE $p_fc]] \
        [get_property INPUT_VALUE $p_st] \
        [expr 0x[get_property INPUT_VALUE $p_acnt]] [expr 0x[get_property INPUT_VALUE $p_aerr]]]
    after 1000
}
close_hw_target
exit 0
