# SOLID 8 色循环, **1-bit BCM** (reg_tunit[11:8]=1)
# 1-bit 没灰度, 只看 bit 0. 颜色用 bit 0 各种组合: R=0x01 G=0x0100 B=0x010000
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# 1-bit BCM: TUNIT[7:0]=1 (display unit), TUNIT[11:8]=1 (1 plane only)
mwr -force 0x40020000 0
after 100
mwr -force 0x40020014 0x00000101   ; # TUNIT=1, planes_n=1
mwr -force 0x40020008 127          ; # 128 col
mwr -force 0x40020000 0x561        ; # en | mode 0 | addr_bits=5 | overlap
after 200

set colors {
    {0x00000001 RED}
    {0x00000100 GREEN}
    {0x00010000 BLUE}
    {0x00000101 YELLOW}
    {0x00010001 MAGENTA}
    {0x00010100 CYAN}
    {0x00010101 WHITE}
    {0x00000000 BLACK}
}

for {set loop 0} {$loop < 5} {incr loop} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        mwr -force 0x40020004 $color
        mwr -force 0x40020010 $color
        puts "=> $name 0x[format %06x $color]"
        after 4000
    }
}
puts "DONE 5 loops"
exit 0
