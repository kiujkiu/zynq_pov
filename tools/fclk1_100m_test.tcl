# 测 FCLK1 75M → 100M 升频后 panel fps
# IO_PLL = 1800M, DIVISOR1*DIVISOR0 = 18 → 100M (DIVISOR1=3, DIVISOR0=6)
# 新 reg value = 0x00300600
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

puts "===== BEFORE FCLK1 升频 ====="
puts "FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"

# 测 fps @ 75M
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "75M FCLK1 fps ≈ [expr {$df / 2.0}]"

puts "===== APPLY FCLK1 = 100M ====="
# 0x00300600 = DIVISOR1=3 << 20 | DIVISOR0=6 << 8 | SRCSEL=0 (IO_PLL)
mwr -force 0xF8000180 0x00300600
after 100
puts "FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"
puts "FCLK1 = 1800M / (3*6) = 100 MHz, DCLK_DIV=2 → DCLK=50M (超 FM6124 spec 30M ×67%)"

# 重新测 fps
after 500
set s3 [mrd -force -value 0x4002000C 1]
set fc3 [expr {([lindex $s3 0] >> 16) & 0xFFFF}]
after 2000
set s4 [mrd -force -value 0x4002000C 1]
set fc4 [expr {([lindex $s4 0] >> 16) & 0xFFFF}]
set df2 [expr {($fc4 - $fc3) & 0xFFFF}]
puts "100M FCLK1 fps ≈ [expr {$df2 / 2.0}]"

puts "===== STATUS check ====="
puts "CTRL    [mrd -force 0x40020000 1]"
puts "PARAM   [mrd -force 0x40020008 1] (width_max+1)"
puts "TUNIT   [mrd -force 0x40020014 1]"
puts "STATUS  [mrd -force 0x4002000C 1] (running bit + frame_count)"
exit 0
