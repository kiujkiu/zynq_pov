# 写 fb 棋盘格 pattern (每像素 R on/off, 验证每 LED 准确控制)
# panel 128 col × 64 row, top 32 row 用 fb_top, bot 32 row 用 fb_bot
# pixel (x, y): on iff (x + y) is even → R=0xFF (亮红); odd → 0 (灭)
# 棋盘 1×1 像素粒度
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

puts "写 fb_top 32 row × 128 col 1×1 棋盘 (R on/off)..."
for {set r 0} {$r < 32} {incr r} {
    for {set c 0} {$c < 128} {incr c} {
        set on [expr {(($r + $c) & 1) == 0}]
        set color [expr {$on ? 0x0000FF : 0x000000}]
        mwr [expr {0x40028000 + ($r * 128 + $c) * 4}] $color
    }
    if {($r & 7) == 7} { puts "  row $r done" }
}

puts "写 fb_bot 32 row × 128 col 1×1 棋盘..."
for {set r 0} {$r < 32} {incr r} {
    for {set c 0} {$c < 128} {incr c} {
        # panel row = r + 32 (in panel coords for bot half)
        set on [expr {(($r + 32 + $c) & 1) == 0}]
        set color [expr {$on ? 0x0000FF : 0x000000}]
        mwr [expr {0x4002C000 + ($r * 128 + $c) * 4}] $color
    }
    if {($r & 7) == 7} { puts "  bot row $r done" }
}

# 切 use_fb=1, mode 0
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
