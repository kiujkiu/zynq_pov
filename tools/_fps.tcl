# 读 frame_count(0x4002000C[31:16]) 间隔测 fps
connect
after 300
targets -set -nocase -filter {name =~ "*Cortex*#0*" || name =~ "ARM*#0"}
configparams force-mem-access 1
set t1 [expr {[mrd -force -value 0x4002000C] >> 16}]
after 2000
set t2 [expr {[mrd -force -value 0x4002000C] >> 16}]
set d [expr {($t2 - $t1) & 0xFFFF}]
puts "FPS: frame_count $t1 -> $t2, delta=$d in 2s => [expr {$d/2}] fps"
exit
