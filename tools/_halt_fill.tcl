connect
after 800
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set v [lindex $argv 0]
mwr -force 0x40028000 $v 4096
mwr -force 0x4002C000 $v 4096
mwr -force 0x40038000 $v 4096
mwr -force 0x4003C000 $v 4096
puts "FILLED $v"
exit 0
