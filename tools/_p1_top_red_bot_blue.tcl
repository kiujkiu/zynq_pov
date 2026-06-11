# panel 1 Verilog fb_top (panel hw rows 0..31) = RED
# panel 1 Verilog fb_bot (panel hw rows 32..63) = BLUE
# 看 viewer 上 RED 和 BLUE 分别在哪 → 反推 panel 1 物理装方向
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]   ; # fb_top Verilog instance
set FB_BOT1 [expr {$BASE + 0xC000}]   ; # fb_bot Verilog instance
mwr -force $BASE 0
after 100
mwr -force 0xF8000180 0x00500500
puts "fill fb_top1 (panel hw rows 0..31) with RED..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x000000FF
}
puts "fill fb_bot1 (panel hw rows 32..63) with BLUE..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x00FF0000
}
mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "done"
exit 0
