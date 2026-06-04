# Runtime 切 BCM planes (arg = 1..6), 保留 t_unit + 测 fps
if {$argc < 1} { puts "usage: set_planes.tcl <N>"; exit 1 }
set planes [lindex $argv 0]
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set cur [lindex [mrd -force -value 0x40020014 1] 0]
set t_unit_low [expr {$cur & 0xFF}]
set new [expr {($t_unit_low) | ($planes << 8)}]
mwr -force 0x40020014 $new
after 100
puts "TUNIT now [mrd -force 0x40020014 1] (planes_n=$planes, t_unit=$t_unit_low)"
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "${planes}-bit BCM fps ≈ [expr {$df / 2.0}]"
exit 0
