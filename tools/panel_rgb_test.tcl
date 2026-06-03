# 三色循环测试 — 先 stop ARM, 然后依次写 R/G/B 全 panel
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

# 阶段由命令行参数 1 选择: R/G/B/W/OFF
set mode [lindex $argv 0]
switch $mode {
    R   { fill_panel 0x0000003F; puts "RED filled" }
    G   { fill_panel 0x00003F00; puts "GREEN filled" }
    B   { fill_panel 0x003F0000; puts "BLUE filled" }
    W   { fill_panel 0x003F3F3F; puts "WHITE filled" }
    OFF { fill_panel 0x00000000; puts "OFF" }
    default { puts "usage: ... R|G|B|W|OFF"; exit 1 }
}
exit 0
