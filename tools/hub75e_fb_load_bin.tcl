# 用 mwr -bin-file 一次性写 fb_top.bin + fb_bot.bin (16 KB each)
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

# swap fb_top.bin ↔ fb_bot.bin 地址 (panel 两块 128×32 物理拼接顺序反)
# fb_top.bin (cell row 0-1, 数字 0-15) → 0x4002C000 (panel 下半)
# fb_bot.bin (cell row 2-3, 数字 16-31) → 0x40028000 (panel 上半, 实际是 panel 上块)
puts "loading fb_top.bin → 0x4002C000 (swapped to bot bank)..."
mwr -bin -file "D:/workspace/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096

puts "loading fb_bot.bin → 0x40028000 (swapped to top bank)..."
mwr -bin -file "D:/workspace/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096

# 切 use_fb=1, mode 0
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
