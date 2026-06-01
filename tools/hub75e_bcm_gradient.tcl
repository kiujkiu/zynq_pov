connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
set color [lindex $argv 0]
mwr 0x40020010 0
mwr 0x40020004 $color
mwr 0x40020000 0x00000501
after 200
puts "COLOR=[format 0x%06x [mrd -value 0x40020004]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
