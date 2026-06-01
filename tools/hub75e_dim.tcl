# 降低 panel 亮度: 设 BCM T_unit 小值
# 默认 96 cycle (~1.28 µs @ 75 MHz), panel 亮但摄像头过曝
# 改小值 → 每 plane OE on 时间短 → panel 暗
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

set tunit [lindex $argv 0]
if {$tunit eq ""} { set tunit 24 }   ;# 默认 24 (=1/4 原亮度)

puts "set TUNIT = $tunit (默认 96, 改小变暗)"
mwr 0x40020014 $tunit
after 100
puts "TUNIT reg = [format 0x%08x [mrd -value 0x40020014]]"
disconnect
exit 0
