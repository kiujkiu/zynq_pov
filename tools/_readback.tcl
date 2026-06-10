connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL  = [mrd -force 0x40020000 1]"
puts "TUNIT = [mrd -force 0x40020014 1]"
puts "PLNS  = [mrd -force 0x40020008 1]"
puts "STATUS = [mrd -force 0x40020004 1]"
puts "BRAM[0] @0x40028000 = [mrd -force 0x40028000 4]"
puts "BRAM[0] @0x40038000 = [mrd -force 0x40038000 4]"
exit 0
