# 只写寄存器切 mode/颜色, 不重烧 fpga/不 ps7_init (bit 已在跑)
# 用法: xsct _setcolor.tcl <mode> <color24hex>   color = {B,G,R} 低字节R
set mode [lindex $argv 0]
set col  [lindex $argv 1]
set ctrl [expr {0x1 | ($mode << 1) | 0x500}]
connect
after 500
targets -set -nocase -filter {name =~ "*Cortex*#0*" || name =~ "ARM*#0"}
configparams force-mem-access 1
mwr -force 0x40020000 0
after 50
mwr -force 0x40020004 $col
mwr -force 0x40020010 $col
mwr -force 0x40020008 127
mwr -force 0x40020014 16
mwr -force 0x40020000 $ctrl
after 300
puts "MODE=$mode COL=[format 0x%X $col] CTRL=[format 0x%X [mrd -force -value 0x40020000]] STATUS=[format 0x%08X [mrd -force -value 0x4002000C]]"
exit
