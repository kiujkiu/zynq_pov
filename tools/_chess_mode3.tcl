connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
# test_mode=3 → BLUE/GREEN chess 内置 LUT
mwr -force $BASE 0x507
after 200
puts "CTRL=[mrd -force $BASE 1] STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
