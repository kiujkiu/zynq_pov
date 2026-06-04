# v29: 改 FSM 跳 S_BLANK + ADDR_SET_CYC 2→1, 测 16 col / TUNIT=1 / FCLK1=72M (DCLK 36M) 下 fps
# 预期 v28 baseline 8170 → v29 ~9000 fps (省 2 cyc/plane × 6 plane × 32 row × 13.9ns ≈ 5.3µs/帧)
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# FCLK1 = 1800/(5*5) = 72 MHz (DCLK_DIV=2 → DCLK 36 MHz, 超 FM6124 spec 30M ×20%)
puts "===== SET FCLK1 = 72M ====="
mwr -force 0xF8000180 0x00500500
after 200
puts "FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"

puts "===== APPLY w=16 TUNIT=1 OVERLAP ====="
mwr -force 0x40020000 0          ; # disable
after 100
mwr -force 0x40020008 15         ; # width_max=15 → 16 col
mwr -force 0x40020014 1          ; # TUNIT=1
mwr -force 0x40020000 0x561      ; # en | mode0 | addr_bits=5 | overlap
after 500
puts "CTRL    [mrd -force 0x40020000 1]"
puts "PARAM   [mrd -force 0x40020008 1]"
puts "TUNIT   [mrd -force 0x40020014 1]"
puts "STATUS  [mrd -force 0x4002000C 1]"

# 测 fps 2s
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "v29 fps ≈ [expr {$df / 2.0}] (df=$df / 2s)"

# 填纯白让 panel 亮 (mode 0 SOLID 用 COLOR register)
mwr -force 0x40020004 0x003F3F3F
mwr -force 0x40020010 0x003F3F3F
after 200
puts "panel SOLID white, 看波形/亮度"
exit 0
