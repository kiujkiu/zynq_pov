connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00300700   ; # 7x3=21 -> 85.71M, DCLK 42.9M
after 500
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
puts "FCLK1=85.7M: fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
