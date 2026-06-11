# 改 PS7 FCLK1 + 测 fps
# arg: hex reg value (e.g., 0x00400600 = 75M, 0x00500400 = 90M, 0x00300600 = 100M)
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set reg_val [lindex $argv 0]
mwr -force 0xF8000180 $reg_val
after 200
puts "FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"

# 测 fps 2s
set s1 [mrd -force -value 0x4002000C 1]
set fc1 [expr {([lindex $s1 0] >> 16) & 0xFFFF}]
after 2000
set s2 [mrd -force -value 0x4002000C 1]
set fc2 [expr {([lindex $s2 0] >> 16) & 0xFFFF}]
set df [expr {($fc2 - $fc1) & 0xFFFF}]
puts "fps ≈ [expr {$df / 2.0}]"
exit 0
