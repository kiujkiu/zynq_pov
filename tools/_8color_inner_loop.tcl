# xsdb 一次连接, 内部 while loop 持续 fill 颜色, 不退出 = panel 不熄灭
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# 设 overlap mode (不 disable)
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561
after 100
puts "panel ON, OVERLAP mode, starting loop..."

set colors [list 0x00003F 0x003F00 0x3F0000 0x3F3F3F 0x003F3F 0x3F003F 0x3F3F00]
set names  [list R G B W Y M C]
set idx 0
while {1} {
    set c [lindex $colors $idx]
    set n [lindex $names $idx]
    mwr -force 0x40028000 $c 4096
    mwr -force 0x4002C000 $c 4096
    mwr -force 0x40038000 $c 4096
    mwr -force 0x4003C000 $c 4096
    puts "[clock format [clock seconds] -format %H:%M:%S] $n"
    after 2000
    incr idx
    if {$idx >= 7} { set idx 0 }
}
