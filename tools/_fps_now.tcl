connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
puts "fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}] CTRL=[format 0x%X [mrd -force -value 0x40020000]] TUNIT=[format 0x%X [mrd -force -value 0x40020014]]"
exit 0
