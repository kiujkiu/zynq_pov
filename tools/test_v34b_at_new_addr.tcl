# v34b dual panel test @ new addr 0x40010000 (BD recreate 后)
# 强制 mode 0 SOLID white, 验证 panel 1 + panel 2 mirror
connect
after 300
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
puts "panel base = $BASE"

# FCLK1 = 72M (DCLK 36M)
mwr -force 0xF8000180 0x00500500
after 200

mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x8}] 127         ; # PARAM width_max=127 (128 col)
mwr -force [expr {$BASE + 0x14}] 0x00000308 ; # TUNIT: 3-bit BCM, t_unit=8
mwr -force [expr {$BASE + 0x4}] 0x001F1F1F  ; # COLOR top white 50%
mwr -force [expr {$BASE + 0x10}] 0x001F1F1F ; # COLOR bot white 50%
mwr -force $BASE 0x561                       ; # enable | mode 0 | overlap
after 500

puts "CTRL    [mrd -force $BASE 1]"
puts "PARAM   [mrd -force [expr {$BASE + 0x8}] 1]"
puts "TUNIT   [mrd -force [expr {$BASE + 0x14}] 1]"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"

# 测 fps
set s1 [mrd -force -value [expr {$BASE + 0xC}] 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value [expr {$BASE + 0xC}] 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "v34b dual mirror @ FCLK1=72M, 3-bit, 128 col, white: fps ≈ [expr {$df / 2.0}]"
exit 0
