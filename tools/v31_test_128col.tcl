# v31 ICND2047: 测 128 col × 32 row, sweep bcm_planes 1/2/6 + FCLK1 50/72M
# 跟 v28 FM6124 baseline (~1130 fps @ 128 col 6-bit) 对比
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

proc set_panel { fclk planes_n } {
    mwr -force 0x40020000 0          ; # disable
    after 100
    mwr -force 0xF8000180 $fclk
    after 200
    mwr -force 0x40020008 127        ; # width_max=127 → 128 col
    # TUNIT[7:0]=1 (default unit), TUNIT[11:8]=planes_n
    set tunit_val [expr {1 | ($planes_n << 8)}]
    mwr -force 0x40020014 $tunit_val
    mwr -force 0x40020004 0x003F3F3F ; # white
    mwr -force 0x40020010 0x003F3F3F
    mwr -force 0x40020000 0x501      ; # en | mode 0 | addr_bits=5
    after 500
}

proc measure_fps {} {
    set s1 [mrd -force -value 0x4002000C 1]
    set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
    after 2000
    set s2 [mrd -force -value 0x4002000C 1]
    set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
    set df [expr {($fc2 - $fc1) & 0xFFFF}]
    return [expr {$df / 2.0}]
}

# Test matrix: FCLK1 × bcm_planes
foreach fclk_pair { {0x00600600 "50M"} {0x00500500 "72M"} } {
    set fclk [lindex $fclk_pair 0]
    set fclk_lbl [lindex $fclk_pair 1]
    foreach planes { 1 2 6 } {
        set_panel $fclk $planes
        set fps [measure_fps]
        puts "ICND2047 128col / ${planes}-bit BCM @ FCLK1=$fclk_lbl: ${fps} fps"
    }
}

# 留在 72M / 6-bit / SOLID white 状态
set_panel 0x00500500 6
puts "STATUS [mrd -force 0x4002000C 1]"
puts "panel left at FCLK1=72M / 6-bit BCM SOLID white"
exit 0
