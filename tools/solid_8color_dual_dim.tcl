# v34b dual panel 8 色循环, panel base @ 0x40010000, 6-bit BCM, 25% 亮度
connect
after 300
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000

# FCLK1 = 72M
mwr -force 0xF8000180 0x00500500
after 200

mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000001 ; # TUNIT=1, planes=default 6
mwr -force [expr {$BASE + 0x8}] 127          ; # 128 col
mwr -force $BASE 0x561                        ; # en | mode 0 | overlap
after 200

# 颜色用 0x0F (~24% 亮度) — 减 R 让接近平衡: R=0x05, G=0x0E, B=0x0F (compensated)
set colors {
    {0x0000000F RED}
    {0x00000F00 GREEN}
    {0x000F0000 BLUE}
    {0x00000F0F YELLOW}
    {0x000F000F MAGENTA}
    {0x000F0F00 CYAN}
    {0x000F0F0F WHITE}
    {0x00000000 BLACK}
}

for {set loop 0} {$loop < 6} {incr loop} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        mwr -force [expr {$BASE + 0x4}] $color
        mwr -force [expr {$BASE + 0x10}] $color
        puts "=> $name 0x[format %06x $color]"
        after 4000
    }
}
puts "DONE 6 loops"
exit 0
