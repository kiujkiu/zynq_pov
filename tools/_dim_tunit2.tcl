connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force [expr {$BASE + 0x14}] 0x00000002
after 100
puts "TUNIT=2 (was 8, dimmer for camera)"
exit 0
