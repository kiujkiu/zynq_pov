connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "SLICE_MODE(0x50)=[mrd -force -value 0x43C20050]"
puts "SLICE_THICK(0x58)=[mrd -force -value 0x43C20058]"
puts "N_SLOTS(0x48)=[mrd -force -value 0x43C20048]"
puts "PHASE(0x40)=[mrd -force -value 0x43C20040]"
exit 0
