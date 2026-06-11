# 写 4 BRAM: panel 1 = 黑 (00), panel 2 = 白 (FFFFFF), use_fb=1, 看 panel 2 是否亮白
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 50
mwr -force 0xF8000180 0x00500500  ; # FCLK1=72M
after 50

set FB_TOP1 [expr {$BASE + 0xC000}]
set FB_BOT1 [expr {$BASE + 0x8000}]
set FB_TOP2 [expr {$BASE + 0x1C000}]
set FB_BOT2 [expr {$BASE + 0x18000}]

# Fill panel 1 with BLACK (0x00) — 4096 words
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0
    mwr -force [expr {$FB_BOT1 + $i*4}] 0
}
puts "panel 1 BRAM cleared to 0"

# Fill panel 2 with WHITE (0xFFFFFF) — 4096 words
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP2 + $i*4}] 0x00FFFFFF
    mwr -force [expr {$FB_BOT2 + $i*4}] 0x00FFFFFF
}
puts "panel 2 BRAM filled with 0x00FFFFFF (white)"

mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561  ; # use_fb=1, mode 0
after 200
puts "CTRL=[mrd -force $BASE 1]"
exit 0
