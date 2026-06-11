# FCLK1 72->75MHz: 0xF8000180 div1[25:20] div0[13:8], IOPLL 1800M
# 0x00500500 = 5x5 = 72M; 0x00400600 = 4x6 = 75M
connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00400600
after 500
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
puts "FCLK1=75M: fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
