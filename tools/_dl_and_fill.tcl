# Combined: download bit + ps7_init + fill color (argv 0 = color idx)

set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
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
mwr -force 0xF8000180 0x00500500
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127

proc fill_color {color name FB_TOP1 FB_BOT1 FB_TOP2 FB_BOT2} {
    puts "fill $name ([format 0x%06X $color])"
    for {set i 0} {$i < 4096} {incr i} {
        mwr -force [expr {$FB_TOP1 + $i*4}] [format "0x%08X" $color]
        mwr -force [expr {$FB_BOT1 + $i*4}] [format "0x%08X" $color]
        mwr -force [expr {$FB_TOP2 + $i*4}] [format "0x%08X" $color]
        mwr -force [expr {$FB_BOT2 + $i*4}] [format "0x%08X" $color]
    }
}

set color_idx [lindex $argv 0]
set colors [list 0x00003F 0x003F00 0x3F0000 0x3F3F3F 0x003F3F 0x3F003F 0x3F3F00]
set names  [list R G B W Y M C]
set c [lindex $colors $color_idx]
set n [lindex $names  $color_idx]
fill_color $c $n $FB_TOP1 $FB_BOT1 $FB_TOP2 $FB_BOT2
mwr -force $BASE 0x521
after 200
puts "set $n (idx=$color_idx) done"
exit 0
