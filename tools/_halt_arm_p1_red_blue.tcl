# Halt ARM first to avoid overwrites, then fill panel 1 top RED / bot BLUE
connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]
set FB_BOT1 [expr {$BASE + 0xC000}]
mwr -force $BASE 0
after 100
mwr -force 0xF8000180 0x00500500
puts "fill fb_top1 with RED (panel hw rows 0..31)..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x000000FF
}
puts "fill fb_bot1 with BLUE (panel hw rows 32..63)..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x00FF0000
}
mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "done - ARM halted, panel 1: top RED, bot BLUE"
exit 0
