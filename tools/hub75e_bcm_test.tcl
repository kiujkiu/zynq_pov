# BCM 验证: 全白 → 50% 灰 → 25% 灰 → 12.5% 灰 → 6% 灰
# 如果 BCM 工作, panel 应显示越来越暗的白色
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

proc step {label color} {
    puts ""
    puts "=== $label ==="
    puts "  set COLOR = [format 0x%06x $color]"
    mwr 0x40020010 0           ;# COLOR_BOT = 0 → 跟 top 同色
    mwr 0x40020004 $color
    mwr 0x40020000 0x00000501  ;# CTRL: enable + mode 0 SOLID + ABCDE + 1/32 scan
    after 100
    set st [mrd -value 0x4002000C]
    puts "  STATUS = [format 0x%08x $st]  plane=[expr {($st >> 13) & 0x7}]"
    after 5000
}

step "1. FULL WHITE (R=G=B=255)"   0xFFFFFF
step "2. 50% gray  (R=G=B=128)"    0x808080
step "3. 25% gray  (R=G=B=64)"     0x404040
step "4. 12% gray  (R=G=B=32)"     0x202020
step "5. 6% gray   (R=G=B=16)"     0x101010
step "6. pure RED  full   (R=255)" 0x0000FF
step "7. 50% red  (R=128)"         0x000080
step "8. RGB mix  (Y=255 ramp)"    0x80FF80

disconnect
exit 0
