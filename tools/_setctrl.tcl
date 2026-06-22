# 直接写 CTRL + TUNIT. 用法: xsct _setctrl.tcl <ctrl_hex> <tunit>
set ctrl [lindex $argv 0]; set tu [lindex $argv 1]
connect
after 400
targets -set -nocase -filter {name =~ "*Cortex*#0*" || name =~ "ARM*#0"}
configparams force-mem-access 1
mwr -force 0x40020000 0
mwr -force 0x40020014 $tu
mwr -force 0x40020008 127
mwr -force 0x40020000 $ctrl
after 300
puts "CTRL=[format 0x%X [mrd -force -value 0x40020000]] STATUS=[format 0x%08X [mrd -force -value 0x4002000C]]"
exit
