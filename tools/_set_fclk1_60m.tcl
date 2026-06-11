# 把 FCLK1 从 72M 改 60M (DCLK 30M spec-compliant)
# IOPLL = 1800M / 5 / 6 = 60M
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000

# 先停 panel (CTRL=0) 防止 clock 切换时 glitch
mwr -force $BASE 0
after 50

# 改 FCLK1
puts "FCLK1 old [mrd -force 0xF8000180 1]"
mwr -force 0xF8000180 0x00600500
after 100
puts "FCLK1 new [mrd -force 0xF8000180 1]"

# 重新启 panel  RED solid
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}]  127
mwr -force [expr {$BASE + 0x4}]  0x0000003F
mwr -force [expr {$BASE + 0x10}] 0x0000003F
mwr -force $BASE 0x501
after 200
puts "CTRL   [mrd -force $BASE 1]"
puts "STATUS [mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
