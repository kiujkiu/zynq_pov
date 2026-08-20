# hw_program.tcl -- 烧调试版 bit + 读 VIO
# -tclargs <bit名不带扩展名>  例: icnd2260_lvds_dbg_div48
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
puts "=== 目标: [current_hw_target] / $dev ==="

set_property PROGRAM.FILE      "$B/$NAME.bit" $dev
set_property PROBES.FILE       "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE  "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
puts "=== 已下载 $NAME ==="

after 2500
set vios [get_hw_vios]
if {[llength $vios] == 0} { puts "=== 没发现 VIO 核 ==="; exit 0 }
set v [lindex $vios 0]
for {set i 0} {$i < 3} {incr i} {
    refresh_hw_vio $v
    puts "--- 第 [expr $i+1] 次读 ---"
    foreach p [lsort [get_hw_probes -of_objects $v]] {
        set nm [get_property NAME $p]
        if {![catch {set val [get_property INPUT_VALUE $p]}]} {
            puts [format "===   %-24s = %s" $nm $val]
        }
    }
    after 1500
}
close_hw_target
