# v30 ICND2047 test: stop ARM, set FCLK1=50M (DCLK 25M ICND2047 spec 内),
# width=16, TUNIT=1, mode 0 SOLID white, 测 fps
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# FCLK1 = 1800 / (6*6) = 50 MHz (DCLK_DIV=2 unused, ICND DDR 1 aclk = 1 bit)
puts "===== SET FCLK1 = 50M (ICND spec 25M, DDR effective 50M) ====="
mwr -force 0xF8000180 0x00600600
after 200
puts "FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"

# 进入 ICND2047 mode 0 SOLID 白色
puts "===== APPLY ICND2047 w=16 TUNIT=1 mode 0 white ====="
mwr -force 0x40020000 0          ; # disable
after 100
mwr -force 0x40020008 15         ; # width_max=15 → 16 col
mwr -force 0x40020014 1          ; # TUNIT=1
mwr -force 0x40020004 0x003F3F3F ; # COLOR top = white
mwr -force 0x40020010 0x003F3F3F ; # COLOR bot = white
mwr -force 0x40020000 0x501      ; # en | mode 0 | addr_bits=5
after 500
puts "CTRL    [mrd -force 0x40020000 1]"
puts "PARAM   [mrd -force 0x40020008 1]"
puts "TUNIT   [mrd -force 0x40020014 1]"
puts "COLOR_T [mrd -force 0x40020004 1]"
puts "COLOR_B [mrd -force 0x40020010 1]"
puts "STATUS  [mrd -force 0x4002000C 1]"

# 测 fps 2s
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "v30 ICND2047 fps @ FCLK1=50M (DCLK 25M) ≈ [expr {$df / 2.0}] (df=$df / 2s)"

puts "===== bump to FCLK1=72M (DCLK 36M, 超 spec 44%) sweep ====="
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
puts "v30 ICND2047 fps @ FCLK1=72M (DCLK 36M) ≈ [expr {$df2 / 2.0}] (df=$df2 / 2s)"

exit 0
