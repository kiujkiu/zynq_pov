connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x4}]  0x0000003F
mwr -force [expr {$BASE + 0x10}] 0x0000003F
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x501
after 200
puts "CTRL=[mrd -force $BASE 1] COLOR=[mrd -force [expr {$BASE + 4}] 1] STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
