connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
# test_mode=7 → FULL WHITE 内置 LUT, 不依赖 reg_color
mwr -force $BASE 0x50F
after 200
puts "CTRL=[mrd -force $BASE 1] STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
