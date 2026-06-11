connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set t [lindex $argv 0]
mwr -force 0x40020014 $t
after 200
puts "TUNIT=[mrd -force 0x40020014 1]"
disconnect
