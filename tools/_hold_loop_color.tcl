# 用 inner-loop 完全相同的代码路径, 但只刷一个颜色 (argv0). 跑 ~25s 给相机抓帧
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561
after 100
set c [lindex $argv 0]
puts "HOLD-LOOP word=$c"
for {set i 0} {$i < 12} {incr i} {
    mwr -force 0x40028000 $c 4096
    mwr -force 0x4002C000 $c 4096
    mwr -force 0x40038000 $c 4096
    mwr -force 0x4003C000 $c 4096
    after 2000
}
disconnect
