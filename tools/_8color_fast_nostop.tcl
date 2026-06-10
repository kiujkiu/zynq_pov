# 快速 fill 一色到 4 BRAM (用 mwr count, 不一个一个写)
connect
after 100
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set color_idx [lindex $argv 0]
set colors [list 0x00003F 0x003F00 0x3F0000 0x3F3F3F 0x003F3F 0x3F003F 0x3F3F00]
set names  [list R G B W Y M C]
set c [lindex $colors $color_idx]
set n [lindex $names  $color_idx]

# mwr addr value count → 写 4096 word 都是同值
mwr -force 0x40028000 $c 4096
mwr -force 0x4002C000 $c 4096
mwr -force 0x40038000 $c 4096
mwr -force 0x4003C000 $c 4096
puts "$n done"
exit 0
