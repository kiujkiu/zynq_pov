connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# STATUS reg @ 0x4002000C: [31:16] = frame_count
set t1 [clock milliseconds]
set s1 [mrd -force 0x4002000C 1]
regexp {([0-9a-fA-F]+)$} $s1 m fc1_hex
set fc1 [expr 0x$fc1_hex]
set fc1 [expr {($fc1 >> 16) & 0xFFFF}]
after 2000
set t2 [clock milliseconds]
set s2 [mrd -force 0x4002000C 1]
regexp {([0-9a-fA-F]+)$} $s2 m fc2_hex
set fc2 [expr 0x$fc2_hex]
set fc2 [expr {($fc2 >> 16) & 0xFFFF}]
set dt [expr {($t2 - $t1) / 1000.0}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "frame_count: $fc1 → $fc2 (delta=$df in ${dt}s)"
puts "fps ≈ [expr {$df / $dt}]"
puts "CTRL = [mrd -force 0x40020000 1]"
exit 0
