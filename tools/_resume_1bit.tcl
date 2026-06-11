connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020014 0x108
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { con }
after 500
puts "RESUMED"
exit 0
