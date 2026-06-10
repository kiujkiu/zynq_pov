# 3 色 LUT mode 循环, 5s/色, 不 disable, 写 reg_color 立即切色
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
# CTRL 一次设 OVERLAP + LUT (use_fb=0), 之后不动
mwr -force 0x40020000 0x00000541
after 100
puts "panel ON, OVERLAP+LUT, 5s R/G/B loop, never blanks"

set colors [list 0x3F0000 0x003F00 0x00003F]
set names  [list R G B]
set idx 0
while {1} {
    set c [lindex $colors $idx]
    set n [lindex $names $idx]
    mwr -force 0x40020004 $c
    mwr -force 0x40020010 $c
    puts "[clock format [clock seconds] -format %H:%M:%S] $n"
    after 5000
    incr idx
    if {$idx >= 3} { set idx 0 }
}
