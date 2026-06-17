# v30 ICND2047 fps 测试 — MTR 转接板 P3 (panel2) + 双下载器按 cable SN 选第二块板
# 跑法: xsdb -> source .../tools/v30_test_p3.tcl
# ---------------------------------------------------------------------------
# 第二块板(ICND2047)的 cable SN. 留空则自动排除第一块板(FM6124, SN 见下).
# 先 connect + 看下面打印的 "所有 targets" 拿到 SN, 填这里最稳:
set SECOND_SN ""
set FIRST_SN  "210251A08870"   ;# 第一块板 cable (memory 记录, 用于自动排除)
# ---------------------------------------------------------------------------

connect
after 500

puts "===================== 所有 JTAG targets (确认 cable SN) ====================="
puts [targets]
puts "============================================================================"

# --- 选第二块板的 APU ---
proc pick_apu {second first} {
    if {$second ne ""} {
        set flt "jtag_cable_serial =~ $second && name =~ APU*"
        puts "\[SEL\] 按指定 SN=$second 选 APU"
    } else {
        set flt "jtag_cable_serial != $first && name =~ APU*"
        puts "\[SEL\] 未填 SN, 自动排除第一块板 SN=$first 选 APU"
    }
    return $flt
}
set apu_flt [pick_apu $SECOND_SN $FIRST_SN]

# 停该板 ARM#0 (同 cable)
if {$SECOND_SN ne ""} {
    set arm_flt "jtag_cable_serial =~ $SECOND_SN && name =~ ARM*#0"
} else {
    set arm_flt "jtag_cable_serial != $FIRST_SN && name =~ ARM*#0"
}
catch { targets -set -nocase -filter $arm_flt ; stop }
after 200
targets -set -nocase -filter $apu_flt
configparams force-mem-access 1
puts "\[SEL\] 选中: [targets -nocase -filter $apu_flt]"

# ===== 50M (DCLK 25M, ICND2047 spec 内) =====
puts "===== FCLK1 = 50M (DCLK 25M) ====="
mwr -force 0xF8000180 0x00600600
after 200
mwr -force 0x40020000 0          ;# disable
after 100
mwr -force 0x40020008 15         ;# width_max=15 -> 16 col
mwr -force 0x40020014 1          ;# TUNIT=1
mwr -force 0x40020004 0x003F3F3F ;# COLOR top = white
mwr -force 0x40020010 0x003F3F3F ;# COLOR bot = white
mwr -force 0x40020000 0x501      ;# en | mode0 | addr_bits=5
after 500
puts "CTRL   [mrd -force 0x40020000 1]"
puts "STATUS [mrd -force 0x4002000C 1]   (\[0\]run \[12:8\]addr \[15:13\]plane \[31:16\]frame)"

set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts ">>> fps @50M (DCLK25M) = [expr {$df/2.0}]  (df=$df /2s)"

# ===== 72M (DCLK 36M, 超 spec 44%) =====
puts "===== FCLK1 = 72M (DCLK 36M, 超频) ====="
mwr -force 0x40020000 0
after 100
mwr -force 0xF8000180 0x00500500
after 200
mwr -force 0x40020000 0x501
after 500
set s3 [mrd -force -value 0x4002000C 1]
set fc3 [expr {([lindex $s3 0] >> 16) & 0xFFFF}]
after 2000
set s4 [mrd -force -value 0x4002000C 1]
set fc4 [expr {([lindex $s4 0] >> 16) & 0xFFFF}]
set df2 [expr {($fc4 - $fc3) & 0xFFFF}]
puts ">>> fps @72M (DCLK36M) = [expr {$df2/2.0}]  (df=$df2 /2s)"

puts "完成. 屏上应为全白. 行错就看上面 STATUS 的 \[12:8\]addr/\[15:13\]plane."
exit 0
