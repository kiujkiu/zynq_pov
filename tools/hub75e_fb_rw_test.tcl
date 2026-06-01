connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

puts ""
puts "=== AXI 写 framebuffer 测试 ==="
# 写 top row 0 col 0..3 不同色, 然后读回
mwr 0x40028000 0x0000FF   ;# top[0,0] = R
mwr 0x40028004 0x00FF00   ;# top[0,1] = G
mwr 0x40028008 0xFF0000   ;# top[0,2] = B
mwr 0x4002800C 0xFFFFFF   ;# top[0,3] = W
# 读回
puts "  top[0,0] = [format 0x%08x [mrd -value 0x40028000]] (期望 0x0000FF)"
puts "  top[0,1] = [format 0x%08x [mrd -value 0x40028004]] (期望 0x00FF00)"
puts "  top[0,2] = [format 0x%08x [mrd -value 0x40028008]] (期望 0xFF0000)"
puts "  top[0,3] = [format 0x%08x [mrd -value 0x4002800C]] (期望 0xFFFFFF)"

# 写 bot row 0 col 0..3
mwr 0x4002C000 0x0000FF
mwr 0x4002C004 0x00FF00
puts "  bot[0,0] = [format 0x%08x [mrd -value 0x4002C000]]"
puts "  bot[0,1] = [format 0x%08x [mrd -value 0x4002C004]]"

# 把整个 framebuffer 填满红色
puts ""
puts "=== 整片填红 (top+bot 各 4096 pixel, 32 KB write) ==="
mwr -size 4 -count 4096 0x40028000 0x0000FF
mwr -size 4 -count 4096 0x4002C000 0x0000FF
puts "  done."

# 确认 CTRL use_fb=1
mwr 0x40020000 0x00000521
puts "  CTRL=[format 0x%08x [mrd -value 0x40020000]]"
disconnect
exit 0
