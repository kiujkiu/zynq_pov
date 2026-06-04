# SOLID 8 色循环, 6-bit BCM, COLOR=0x0F (25% 亮度, 减温)
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

mwr -force 0x40020000 0
after 100
mwr -force 0x40020014 0x00000001   ; # TUNIT=1, planes_n=default 6
mwr -force 0x40020008 127          ; # 128 col
mwr -force 0x40020000 0x561        ; # en | mode 0 | overlap
after 200

# 颜色用 0x0F (bit 0..3 = 15/63 ≈ 24% brightness)
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

for {set loop 0} {$loop < 5} {incr loop} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        mwr -force 0x40020004 $color
        mwr -force 0x40020010 $color
        puts "=> $name 0x[format %06x $color] (25% brightness)"
        after 4000
    }
}
puts "DONE 5 loops"
exit 0
