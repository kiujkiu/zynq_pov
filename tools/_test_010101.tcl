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
puts "fill all 4 BRAMs with 0x010101 (only bit 0 of each chan)..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x00010101
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x00010101
    mwr -force [expr {$FB_TOP2 + $i*4}] 0x00010101
    mwr -force [expr {$FB_BOT2 + $i*4}] 0x00010101
}
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x521
after 300
puts "CTRL=[mrd -force $BASE 1]"
exit 0
