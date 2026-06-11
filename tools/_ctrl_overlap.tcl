connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x5E1   ; # enable|use_fb|overlap|dma_en|abits5
after 300
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
puts "CTRL=[format 0x%X [mrd -force -value 0x40020000]] fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}]"
exit 0
