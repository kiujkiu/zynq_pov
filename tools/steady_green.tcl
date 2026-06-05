# Panel steady GREEN 测波形 (新地址)
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
mwr -force 0xF8000180 0x00500500
after 200
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}] 127
mwr -force [expr {$BASE + 0x4}] 0x003F3F00 ; # GREEN full (bit 8-13 in G byte)
mwr -force [expr {$BASE + 0x10}] 0x003F3F00
mwr -force $BASE 0x561
after 300
puts "panel @ steady CYAN-G full (COLOR=0x003F3F00)"
puts "CTRL [mrd -force $BASE 1]"
puts "STATUS [mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
