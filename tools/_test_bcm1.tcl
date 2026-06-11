connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE     0x40020000
set FB_TOP1  [expr {$BASE + 0x8000}]
set FB_BOT1  [expr {$BASE + 0xC000}]
set FB_TOP2  [expr {$BASE + 0x18000}]
set FB_BOT2  [expr {$BASE + 0x1C000}]
mwr -force $BASE 0
after 50
# fill BRAM with bit 0 only set on R/G/B (so single plane visible at plane 0)
puts "fill 0x010101..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x00010101
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x00010101
    mwr -force [expr {$FB_TOP2 + $i*4}] 0x00010101
    mwr -force [expr {$FB_BOT2 + $i*4}] 0x00010101
}
# BCM=1, TUNIT=64 (16x bigger so visible)
mwr -force [expr {$BASE + 0x14}] 0x00000140
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x521
after 300
puts "CTRL=[mrd -force $BASE 1] TUNIT=[mrd -force [expr {$BASE + 0x14}] 1]"
exit 0
