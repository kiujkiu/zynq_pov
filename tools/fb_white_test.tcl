connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "filling fb_a (0x10000000) with 0xFF (white)..."
# 2.76 MB / 4 = 691200 words. fill 32-bit 0xFFFFFFFF
# mwr loop is slow but works
# 用 mwr -force 一次性写 N 个
# 实际更快: 写一小片测试 (中央 200x200 区域 white)
set base 0x10000000
set stride [expr {1280 * 3}]
# 取 fb 中央 400x200 写白色 (0xFFFFFF)
for {set y 260} {$y < 460} {incr y} {
    set row_base [expr {$base + $y * $stride}]
    for {set x 440} {$x < 840} {incr x 4} {
        set off [expr {$row_base + $x * 3}]
        mwr -force $off 0xFFFFFFFF
    }
}
puts "fb_a center 400x200 filled white. HDMI 应该显示中央白方块."
exit 0
