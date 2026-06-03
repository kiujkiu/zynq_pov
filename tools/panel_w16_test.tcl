# 测试: panel width 128→16, TUNIT 8→1 等比例缩
# 期望 fps 接近 128/16 = 8 倍, 平均亮度不变
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

puts "===== BEFORE ====="
puts "CTRL    [mrd -force 0x40020000 1]"
puts "PARAM   [mrd -force 0x40020008 1]"
puts "TUNIT   [mrd -force 0x40020014 1]"
puts "STATUS  [mrd -force 0x4002000C 1]"

# 读两次 frame_count 算 baseline fps
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "BEFORE fps ≈ [expr {$df / 2.0}] (df=$df / 2s)"

# disable, 改参数, re-enable
puts "===== APPLY w=16 TUNIT=1 ====="
mwr -force 0x40020000 0
after 200
mwr -force 0x40020008 15      ; # width_max=15 → 16 cols
mwr -force 0x40020014 1       ; # TUNIT=1 (8 × 16/128)
mwr -force 0x40020000 0x561   ; # re-enable overlap
after 500

puts "PARAM   [mrd -force 0x40020008 1]"
puts "TUNIT   [mrd -force 0x40020014 1]"

# 重新测 fps
set s3 [mrd -force -value 0x4002000C 1]
set fc3 [expr {([lindex $s3 0] >> 16) & 0xFFFF}]
after 2000
set s4 [mrd -force -value 0x4002000C 1]
set fc4 [expr {([lindex $s4 0] >> 16) & 0xFFFF}]
set df2 [expr {($fc4 - $fc3) & 0xFFFF}]
puts "AFTER  fps ≈ [expr {$df2 / 2.0}] (df=$df2 / 2s)"

exit 0
