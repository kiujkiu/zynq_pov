# 8 色循环 - stop ARM, 然后依次填 8 色每色 4 秒
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

proc fill_panel { color } {
    for {set i 0} {$i < 4096} {incr i} {
        mwr -force [expr {0x4002C000 + $i * 4}] $color
        mwr -force [expr {0x40028000 + $i * 4}] $color
    }
}

set colors {
    {0x00000000 BLACK}
    {0x0000003F RED}
    {0x00003F00 GREEN}
    {0x003F0000 BLUE}
    {0x00003F3F YELLOW}
    {0x003F003F MAGENTA}
    {0x003F3F00 CYAN}
    {0x003F3F3F WHITE}
}

# 无限循环 — 用 kill 进程停止
while {1} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        fill_panel $color
        puts "=> $name"
        after 4000
    }
}
exit 0
