# 用 ARM 写 framebuffer 100 个 pixel 红色 + 100 绿 + 100 蓝
# 切 use_fb=1 看 panel 是否有红绿蓝色块
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

puts "writing 100 RED pixels top row 0 col 0..99..."
for {set i 0} {$i < 100} {incr i} {
    mwr [expr {0x40028000 + $i * 4}] 0x0000FF
}
puts "writing 100 GREEN pixels top row 1 col 0..99..."
for {set i 0} {$i < 100} {incr i} {
    mwr [expr {0x40028000 + (128 + $i) * 4}] 0x00FF00
}
puts "writing 100 BLUE pixels top row 2 col 0..99..."
for {set i 0} {$i < 100} {incr i} {
    mwr [expr {0x40028000 + (256 + $i) * 4}] 0xFF0000
}
puts "writing 100 WHITE pixels top row 3 col 0..99..."
for {set i 0} {$i < 100} {incr i} {
    mwr [expr {0x40028000 + (384 + $i) * 4}] 0xFFFFFF
}

# 切 use_fb=1, mode 0, enable, scan 5
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
