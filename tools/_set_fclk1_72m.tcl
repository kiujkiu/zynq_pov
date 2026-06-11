# 回 72M FCLK1 (DCLK ~36M, 接近 37.5M)
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000

mwr -force $BASE 0
after 50

mwr -force 0xF8000180 0x00500500
after 100
puts "FCLK1 [mrd -force 0xF8000180 1]"

mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}]  127
mwr -force [expr {$BASE + 0x4}]  0x0000003F
mwr -force [expr {$BASE + 0x10}] 0x0000003F
mwr -force $BASE 0x501
after 200
puts "CTRL [mrd -force $BASE 1]"
exit 0
