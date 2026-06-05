# 检查 panel running + ARM state
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
puts "CTRL    [mrd -force $BASE 1]"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"
puts "COLOR_T [mrd -force [expr {$BASE + 0x4}] 1]"
# frame count delta
set s1 [mrd -force -value [expr {$BASE + 0xC}] 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 1000
set s2 [mrd -force -value [expr {$BASE + 0xC}] 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "fps ≈ $df (over 1s)"
# ARM state
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "ARM target: [targets]"
exit 0
