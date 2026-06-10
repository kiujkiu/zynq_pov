# LUT mode 切色, 不动 BRAM, 1 reg 写立即切色 = panel 永不熄灭
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# Setup FCLK + TUNIT + planes + LUT mode (CTRL bit[5]=0 use_fb=0, test_mode=0 走 reg_color)
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
# CTRL = 0x541 = enable + use_fb=0 + overlap_en + addr_bits=5 (0b 0101 0100 0001)
mwr -force 0x40020000 0x00000541
after 100
puts "panel ON, LUT+OVERLAP, starting loop..."

set colors [list 0x3F0000 0x003F00 0x00003F 0x3F3F3F 0x3F3F00 0x3F003F 0x003F3F]
set names  [list R G B W Y M C]
set idx 0
while {1} {
    set c [lindex $colors $idx]
    set n [lindex $names $idx]
    # reg_color (offset 0x4) + reg_color_bot (offset 0x10) 一次写
    mwr -force 0x40020004 $c
    mwr -force 0x40020010 $c
    puts "[clock format [clock seconds] -format %H:%M:%S] $n"
    after 1500
    incr idx
    if {$idx >= 7} { set idx 0 }
}
