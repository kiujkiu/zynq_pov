# 降亮度到 1/2 (0x3F → 0x1F)
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020004 0x001F1F1F
mwr -force 0x40020010 0x001F1F1F
puts "COLOR set to 0x1F1F1F (50% brightness)"
exit 0
