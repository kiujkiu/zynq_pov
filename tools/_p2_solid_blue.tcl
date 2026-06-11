# 只对 panel 2 BRAM 写 SOLID BLUE, panel 1 BRAM 不动 → 验证 panel 2 是否能纯色显示
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP2 [expr {$BASE + 0x1C000}]
set FB_BOT2 [expr {$BASE + 0x18000}]

# 不停 panel, 只覆盖 panel 2 BRAM
puts "filling panel 2 BRAM (both top+bot) with BLUE 0x00FF0000..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP2 + $i*4}] 0x00FF0000
    mwr -force [expr {$FB_BOT2 + $i*4}] 0x00FF0000
}
puts "done - panel 2 should be solid BLUE"
puts "CTRL=[mrd -force $BASE 1]"
exit 0
