# 测当前 fps (不动 panel state)
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "current fps ≈ [expr {$df / 2.0}]"
puts "TUNIT [mrd -force 0x40020014 1] CTRL [mrd -force 0x40020000 1]"
exit 0
