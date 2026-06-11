# panel 1 BRAM 全填 RED, panel 2 BRAM 全填 GREEN, use_fb=1 → 验证左右独立 BRAM 显示
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
mwr -force 0xF8000180 0x00500500
after 50

set FB_TOP1 [expr {$BASE + 0xC000}]
set FB_BOT1 [expr {$BASE + 0x8000}]
set FB_TOP2 [expr {$BASE + 0x1C000}]
set FB_BOT2 [expr {$BASE + 0x18000}]

puts "filling panel 1 with RED 0x000000FF..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x000000FF
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x000000FF
}
puts "filling panel 2 with GREEN 0x0000FF00..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP2 + $i*4}] 0x0000FF00
    mwr -force [expr {$FB_BOT2 + $i*4}] 0x0000FF00
}

mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "done - panel 1 should be RED, panel 2 should be GREEN"
exit 0
