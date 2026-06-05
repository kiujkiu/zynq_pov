connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
# COLOR top = 0x000001 (只 R bit 0, panel 1 + panel 2 R1 chip 微亮)
mwr -force [expr {$BASE + 0x4}] 0x00000001
mwr -force [expr {$BASE + 0x10}] 0x00000001
puts "COLOR=0x000001 (R only, bit 0) - 只 hub75e_rgb[0]=AB22 & hub75e_rgb2[0]=AA19 有信号"
exit 0
