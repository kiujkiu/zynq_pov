# 3-bit BCM (8 灰度/channel, fps 提升 8×) + 保持 anime fb display
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000

# Stop briefly
mwr -force $BASE 0
after 50

# TUNIT register: [7:0]=t_unit=8, [11:8]=bcm_planes=3
mwr -force [expr {$BASE + 0x14}] 0x00000308

# CTRL = 0x561 (en + mode 0 + use_fb + overlap), 跟 anime_load_v34e 一致
mwr -force $BASE 0x561
after 200
puts "TUNIT reg [mrd -force [expr {$BASE + 0x14}] 1]"
puts "CTRL     [mrd -force $BASE 1]"
puts "STATUS   [mrd -force [expr {$BASE + 0xC}] 1]"
puts "3-bit BCM (8 灰度), planes=3, t_unit=8"
exit 0
