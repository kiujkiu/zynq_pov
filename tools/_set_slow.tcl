connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x4002001C 1190476   ; # 85.71M / 72 = 72 slice/s = 5s/圈
after 300
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
