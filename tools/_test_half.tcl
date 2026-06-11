# 用法: xsdb _test_half.tcl <top|bot> <color>
# 只点亮上半 (BASE+0x4) 或下半 (BASE+0x10), 另一半保持 0
# 用来判断 panel 2 上下半 wiring 是否独立错位
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
set half  [lindex $argv 0]
set color [lindex $argv 1]
if {$half eq ""}  { set half "top" }
if {$color eq ""} { set color 0x00000010 }

mwr -force $BASE 0
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}]  127
if {$half eq "top"} {
    mwr -force [expr {$BASE + 0x4}]  $color
    mwr -force [expr {$BASE + 0x10}] 0
    puts "TOP half = $color, BOT = 0"
} else {
    mwr -force [expr {$BASE + 0x4}]  0
    mwr -force [expr {$BASE + 0x10}] $color
    puts "TOP = 0, BOT half = $color"
}
mwr -force $BASE 0x501
after 200
puts "CTRL [mrd -force $BASE 1]"
exit 0
