# v34g Phase 2 dual panel anime display: 128×64 per panel × 2 panels → 4 BRAM regions
# Panel 1: top @ 0x4002C000, bot @ 0x40028000 (addr bit[16]=0)
# Panel 2: top @ 0x4003C000, bot @ 0x40038000 (addr bit[16]=1, v34g new BRAM)
# CTRL=0x561 (en + mode 0 + use_fb + overlap), FCLK1=72M (DCLK 37.5M), TUNIT=8
# v34g base 改到 0x40020000 (128K-aligned, BD address segment 限制)
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0xC000}]    ; # 0x4002C000  panel 1 top half
set FB_BOT1 [expr {$BASE + 0x8000}]    ; # 0x40028000  panel 1 bot half
set FB_TOP2 [expr {$BASE + 0x1C000}]   ; # 0x4003C000  panel 2 top half (bit[16]=1)
set FB_BOT2 [expr {$BASE + 0x18000}]   ; # 0x40038000  panel 2 bot half (bit[16]=1)

# Disable panel during load
mwr -force $BASE 0
after 100

# FCLK1 = 72M (DCLK 37.5M, 用户实测稳)
mwr -force 0xF8000180 0x00500500
after 100
puts "FCLK1 [mrd -force 0xF8000180 1]"

# Load panel 1 top (image rows 0..31)
puts "loading fb_anime_128_top1.bin → 0x[format %X $FB_TOP1]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top1.bin" -size w $FB_TOP1 4096

# Load panel 1 bot (image rows 32..63)
puts "loading fb_anime_128_bot1.bin → 0x[format %X $FB_BOT1]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot1.bin" -size w $FB_BOT1 4096

# Load panel 2 top (image rows 64..95)
puts "loading fb_anime_128_top2.bin → 0x[format %X $FB_TOP2]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top2.bin" -size w $FB_TOP2 4096

# Load panel 2 bot (image rows 96..127)
puts "loading fb_anime_128_bot2.bin → 0x[format %X $FB_BOT2]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot2.bin" -size w $FB_BOT2 4096

# TUNIT=8 sweet spot, 6-bit BCM
mwr -force [expr {$BASE + 0x14}] 8

# CTRL = 0x561 (en | mode 0 | use_fb | overlap)
mwr -force $BASE 0x561

after 300
puts "CTRL    [mrd -force $BASE 1]"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"
puts "v34g Phase 2 anime loaded (128×128 stacked), DCLK 37.5M, panel 1 + panel 2 独立 BRAM"
exit 0
