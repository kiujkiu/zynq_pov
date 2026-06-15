connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0xC5E1   ; # + bit15 sensor_en
after 500
set d [mrd -force -value 0x40020024]
puts "sensor_en=1: locked=[expr {($d>>23)&1}] slice=[expr {$d&0xFFFF}] rev_period=[format 0x%X [mrd -force -value 0x40020028]]"
mwr -force 0x40020000 0x45E1   ; # 回 fake 模式
after 300
puts "back to fake: DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
