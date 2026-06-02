# Load fb_top.bin + fb_bot.bin into HUB75E framebuffer, enable mode 0 SOLID + use_fb
# Run AFTER bit is loaded (dl_v27_diag.tcl-style boot first).
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# panel 两块 128×32 物理拼接顺序反:
# fb_top.bin (cell row 0-1, 数字 0-15) → 写到 0x4002C000 (panel bot bank)
# fb_bot.bin (cell row 2-3, 数字 16-31) → 写到 0x40028000 (panel top bank)
puts "loading fb_top.bin → 0x4002C000 ..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096

puts "loading fb_bot.bin → 0x40028000 ..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096

# TUNIT=32 gives nice brightness without saturation
mwr 0x40020014 32
# CTRL = use_fb(1)<<5 | addr_bits(5)<<8 | mode(0)<<1 | en(1) = 0x521
mwr 0x40020000 0x521
after 200
puts "CTRL=[mrd 0x40020000]"
puts "TUNIT=[mrd 0x40020014]"
puts "STATUS=[mrd 0x4002000C]"
exit 0
