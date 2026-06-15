connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x4002001C 8818   ; # 85.71M / (360x27) = 27 rev/s
after 300
set d1 [mrd -force -value 0x40020024]
set f1 [mrd -force -value 0x4002000C]
after 2000
set d2 [mrd -force -value 0x40020024]
set f2 [mrd -force -value 0x4002000C]
puts "err=[expr {($d2>>28)&0xF}] fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}]"
exit 0
