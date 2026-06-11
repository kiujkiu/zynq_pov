connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]
set FB_BOT1 [expr {$BASE + 0xC000}]
mwr -force $BASE 0
after 100
puts "filling panel 1 with GREEN 0x0000FF00..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x0000FF00
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x0000FF00
}
mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "done"
exit 0
