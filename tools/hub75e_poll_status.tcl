connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
# 切 use_fb=1, mode 0
mwr 0x40020000 0x00000521
# 写一个明亮 pixel
mwr 0x40028000 0xFFFFFF
after 200
# poll STATUS 10 次每次 100 ms
for {set i 0} {$i < 10} {incr i} {
    set st [mrd -value 0x4002000C]
    set plane [expr {($st >> 13) & 0x7}]
    set row   [expr {($st >> 8) & 0x1F}]
    set frame [expr {($st >> 16) & 0xFFFF}]
    puts "  poll $i: STATUS=[format 0x%08x $st]  plane=$plane row=$row frame=$frame"
    after 100
}
disconnect
exit 0
