# 临时方案: 关 enable 让 OE 永远 1 (panel blank, 但 PL 写寄存器还行)
# 然后用 xsdb 直接戳寄存器看 panel 反应
#
# Usage:
#   xsdb hub75e_oe_force.tcl
# 这会循环切几个状态, 每 5 秒一次, 用户肉眼看 panel:
#   1. enable=0 (PL 停, OE=1, panel 黑)
#   2. enable=1 mode=7 FULL_WHITE (现在的状态, 应全亮)
#   3. enable=1 mode=0 COLOR=0x3F (RGB 全 1, 等价 7)
#   4. enable=1 mode=0 COLOR=0x09 (顶半红 R1=1, 底半红 R2=1)
#   5. enable=1 mode=4 ROW_WALK (单行白扫)

connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

proc step {label ctrl color} {
    puts ""
    puts "=== $label ==="
    puts "  CTRL=[format 0x%08x $ctrl]  COLOR=[format 0x%02x $color]"
    mwr 0x40020004 $color
    mwr 0x40020000 $ctrl
    after 100
    set st [mrd -value 0x4002000C]
    puts "  STATUS=[format 0x%08x $st]  running=[expr {$st & 1}]  frame=[expr {($st >> 16) & 0xFFFF}]"
    after 5000
}

step "1. enable=0 panel blank" 0x00000000 0x00
step "2. mode 7 FULL_WHITE"    0x0000050F 0x00
step "3. mode 0 COLOR=0x3F all RGB high" 0x00000501 0x3F
step "4. mode 0 COLOR=R1+R2 only"        0x00000501 0x09
step "5. mode 4 ROW_WALK"                0x00000509 0x00
step "6. holding mode 7"                 0x0000050F 0x00

disconnect
exit 0
