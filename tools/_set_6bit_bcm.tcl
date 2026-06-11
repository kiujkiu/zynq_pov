# 回 6-bit BCM (默认 64 灰度) + 保持 anime fb display
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
mwr -force $BASE 0
after 50
# TUNIT: [7:0]=t_unit=8, [11:8]=0 → 用 default BCM_PLANES=6
mwr -force [expr {$BASE + 0x14}] 0x00000008
mwr -force $BASE 0x561
after 200
puts "TUNIT reg [mrd -force [expr {$BASE + 0x14}] 1]"
puts "CTRL     [mrd -force $BASE 1]"
puts "6-bit BCM (64 灰度), planes=6, t_unit=8"
exit 0
