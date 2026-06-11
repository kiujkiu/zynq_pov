connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x4002001C 1041667   ; # 72 slice/s = 360 片 / 5s 周期
after 300
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
after 2000
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
