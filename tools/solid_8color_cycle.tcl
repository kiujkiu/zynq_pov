# SOLID 8 色循环 (mode 0, COLOR register, 不用 BRAM)
# 用于 FM6124 panel 视觉验证 BCM 灰度
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# 确保 panel 在 mode 0 SOLID + 6-bit BCM + overlap
mwr -force 0x40020000 0
after 100
mwr -force 0x40020014 0x00000001   ; # TUNIT=1, planes_n=default(6)
mwr -force 0x40020008 127          ; # 128 col
mwr -force 0x40020000 0x561        ; # en | mode 0 | addr_bits=5 | overlap
after 200

set colors {
    {0x0000003F RED}
    {0x00003F00 GREEN}
    {0x003F0000 BLUE}
    {0x00003F3F YELLOW}
    {0x003F003F MAGENTA}
    {0x003F3F00 CYAN}
    {0x003F3F3F WHITE}
}

# 4 秒每色循环 (5 圈后退出)
for {set loop 0} {$loop < 5} {incr loop} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        # 降亮度到 50% (0x3F → 0x1F)
        set dim_color [expr {(($color >> 1) & 0x001F1F1F)}]
        mwr -force 0x40020004 $dim_color
        mwr -force 0x40020010 $dim_color
        puts "=> $name (dim 0x[format %x $dim_color])"
        after 4000
    }
}
puts "DONE 5 loops"
exit 0
