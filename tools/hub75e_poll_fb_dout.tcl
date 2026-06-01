# 写 fb 4 行不同色, poll STATUS 看 fb_top_dout 是否随 row/col 变化
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

# 改 STATUS 暂时显示 fb_top_dout 不是 wdata: 需要改 PL 但 quick test 用 wdata 也可
# 用 ARM 写已知 pattern 看 STATUS[31:24] = last fb wdata (sample on last write)

puts "写 fb[0..127] 全 R (0x0000FF)"
for {set i 0} {$i < 128} {incr i} {
    mwr [expr {0x40028000 + $i * 4}] 0x0000FF
}
puts "写 fb[128..255] 全 G (0x00FF00)"
for {set i 128} {$i < 256} {incr i} {
    mwr [expr {0x40028000 + $i * 4}] 0x00FF00
}
puts "写 fb[256..383] 全 B (0xFF0000)"
for {set i 256} {$i < 384} {incr i} {
    mwr [expr {0x40028000 + $i * 4}] 0xFF0000
}
mwr 0x40020000 0x00000521
after 200
puts ""
puts "=== poll STATUS 16 次, 看 last_fb_wdata (最后一次 fb write) vs running state ==="
for {set i 0} {$i < 16} {incr i} {
    set st [mrd -value 0x4002000C]
    puts "  $i: STATUS=[format 0x%08x $st] last_wdata[7:0]=[format 0x%02x [expr {($st >> 24) & 0xFF}]] we_cnt[7:0]=[format 0x%02x [expr {($st >> 16) & 0xFF}]] plane=[expr {($st >> 13) & 0x7}] row=[expr {($st >> 8) & 0x1F}]"
    after 30
}
disconnect
exit 0
