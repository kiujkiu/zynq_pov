# 修: mode 0 SOLID, NO use_fb (CTRL=0x501), 读 COLOR register
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
mwr -force [expr {$BASE + 0x4}] 0x0000003F  ; # pure RED
mwr -force [expr {$BASE + 0x10}] 0x0000003F
mwr -force $BASE 0x501                       ; # en | mode 0 | NO use_fb | NO overlap
after 300
puts "CTRL    [mrd -force $BASE 1] (use_fb=0, mode 0 SOLID)"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"
puts "panel @ pure RED 0x3F, mode 0 SOLID without use_fb"
exit 0
