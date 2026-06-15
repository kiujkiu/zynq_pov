connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 [lindex $argv 0]
after 300
puts "FCLK set [lindex $argv 0]"
disconnect
