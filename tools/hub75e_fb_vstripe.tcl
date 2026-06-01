connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
# 写 fb vstripe 8 色 (每 16 col 一色), 64 row × 128 col
# row r, col c, fb idx (top: r*128+c, bot: (r-32)*128+c)
# color LUT: R G B W Y M C K (24-bit, R[7:0] G[15:8] B[23:16])
set colors [list 0x0000FF 0x00FF00 0xFF0000 0xFFFFFF 0x00FFFF 0xFF00FF 0xFFFF00 0x000000]
puts "writing 64 rows × 128 col vstripe (8 colors × 16 col each)..."
# 顶半 row 0..31
for {set r 0} {$r < 32} {incr r} {
    for {set c 0} {$c < 128} {incr c} {
        set color [lindex $colors [expr {($c / 16) & 7}]]
        mwr [expr {0x40028000 + ($r * 128 + $c) * 4}] $color
    }
}
puts "  顶半 done"
# 底半 row 32..63
for {set r 0} {$r < 32} {incr r} {
    for {set c 0} {$c < 128} {incr c} {
        set color [lindex $colors [expr {($c / 16) & 7}]]
        mwr [expr {0x4002C000 + ($r * 128 + $c) * 4}] $color
    }
}
puts "  底半 done"
mwr 0x40020000 0x00000521
after 200
puts "STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
