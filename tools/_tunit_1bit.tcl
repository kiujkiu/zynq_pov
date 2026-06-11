connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020014 0x108
after 300
puts "TUNIT=[format 0x%X [mrd -force -value 0x40020014]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
