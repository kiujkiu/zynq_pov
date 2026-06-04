# v32 FM6124 + runtime planes: 测 128 col × 32 row, sweep bcm_planes 1/2/6 + FCLK1 50/72M
# 跟 v31 ICND2047 直接对比
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

proc set_panel { fclk planes_n overlap_en } {
    mwr -force 0x40020000 0          ; # disable
    after 100
    mwr -force 0xF8000180 $fclk
    after 200
    mwr -force 0x40020008 127        ; # width_max=127 → 128 col
    set tunit_val [expr {1 | ($planes_n << 8)}]
    mwr -force 0x40020014 $tunit_val
    mwr -force 0x40020004 0x003F3F3F
    mwr -force 0x40020010 0x003F3F3F
    # CTRL: en | mode 0 | addr_bits 5 (<<8) + optional overlap (<<6)
    set ctrl_val [expr {0x501 | ($overlap_en << 6)}]
    mwr -force 0x40020000 $ctrl_val
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

# Test matrix: FCLK1 × bcm_planes × overlap (0/1)
foreach fclk_pair { {0x00600600 "50M"} {0x00500500 "72M"} } {
    set fclk [lindex $fclk_pair 0]
    set fclk_lbl [lindex $fclk_pair 1]
    foreach overlap { 0 1 } {
        set ov_lbl [expr {$overlap == 0 ? "SER" : "OVL"}]
        foreach planes { 1 2 6 } {
            set_panel $fclk $planes $overlap
            set fps [measure_fps]
            puts "FM6124 128col / ${planes}-bit BCM / $ov_lbl @ FCLK1=$fclk_lbl: ${fps} fps"
        }
    }
}

set_panel 0x00500500 6 1
puts "STATUS [mrd -force 0x4002000C 1]"
puts "panel left at FCLK1=72M / 6-bit BCM OVERLAP SOLID white"
exit 0
