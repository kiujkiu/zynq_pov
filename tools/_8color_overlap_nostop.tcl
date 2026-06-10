# 8 color cycle 不 disable panel, 直接 fill + 保持 CTRL=0x561 (OVERLAP)
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE     0x40020000
set FB_TOP1  [expr {$BASE + 0x8000}]
set FB_BOT1  [expr {$BASE + 0xC000}]
set FB_TOP2  [expr {$BASE + 0x18000}]
set FB_BOT2  [expr {$BASE + 0x1C000}]

set color_idx [lindex $argv 0]
set colors [list 0x00003F 0x003F00 0x3F0000 0x3F3F3F 0x003F3F 0x3F003F 0x3F3F00]
set names  [list R G B W Y M C]
set c [lindex $colors $color_idx]
set n [lindex $names  $color_idx]
puts "fill $n ([format 0x%06X $c])"
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] [format "0x%08X" $c]
    mwr -force [expr {$FB_BOT1 + $i*4}] [format "0x%08X" $c]
    mwr -force [expr {$FB_TOP2 + $i*4}] [format "0x%08X" $c]
    mwr -force [expr {$FB_BOT2 + $i*4}] [format "0x%08X" $c]
}
# 不 touch CTRL — 维持当前显示状态 (OVERLAP CTRL=0x561 已被前面设过)
puts "set $n (idx=$color_idx) done, panel stays lit"
exit 0
