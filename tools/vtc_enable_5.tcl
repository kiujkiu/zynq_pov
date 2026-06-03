connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x43C00000 0x00000005
after 200
puts "CTRL=[mrd -force 0x43C00000 1]  ERROR=[mrd -force 0x43C00010 1]"
exit 0
