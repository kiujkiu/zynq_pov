connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
mwr -force [expr {$BASE + 0x4}] 0x0000003F
mwr -force [expr {$BASE + 0x10}] 0x0000003F
puts "panel set to pure RED 0x0000003F"
exit 0
