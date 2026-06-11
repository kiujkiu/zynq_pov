# v34e dual panel anime display: 128×64 → panel BRAM, CTRL=0x561 (use_fb + overlap), FCLK1=72M (DCLK 37.5M)
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
set FB_TOP [expr {$BASE + 0xC000}]   ; # 0x4001C000
set FB_BOT [expr {$BASE + 0x8000}]   ; # 0x40018000

# Disable panel during load
mwr -force $BASE 0
after 100

# FCLK1 = 72M (DCLK 37.5M, 用户实测稳)
mwr -force 0xF8000180 0x00500500
after 100
puts "FCLK1 [mrd -force 0xF8000180 1]"

# Load anime fb_top (panel rows 0..31, top half)
puts "loading fb_anime_top.bin → 0x[format %X $FB_TOP]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_top.bin" -size w $FB_TOP 4096

# Load fb_bot (panel rows 32..63, bot half)
puts "loading fb_anime_bot.bin → 0x[format %X $FB_BOT]..."
mwr -force -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_bot.bin" -size w $FB_BOT 4096

# TUNIT=8 sweet spot, BCM tuning
mwr -force [expr {$BASE + 0x14}] 8

# CTRL = 0x561 (en | mode 0 | use_fb | overlap)
mwr -force $BASE 0x561

after 300
puts "CTRL    [mrd -force $BASE 1]"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"
puts "Anime loaded, DCLK 37.5M, mirror to panel 1 + panel 2"
exit 0
