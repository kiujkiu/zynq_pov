# 烧一个不带调试核的 bit (没有 .ltx, 只能看板载 LED)
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_bit"
set NAME "icnd2260_ttl"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROGRAM.FILE "$B/$NAME.bit" $dev
program_hw_devices $dev
puts "=== 已烧录 $NAME ==="
close_hw_target
