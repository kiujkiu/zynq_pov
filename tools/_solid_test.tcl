connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set c [lindex $argv 0]
mwr -force 0xF8000180 0x00300700
mwr -force 0x40020014 0x608
mwr -force 0x40020008 127
mwr -force 0x40028000 $c 4096
mwr -force 0x4002C000 $c 4096
mwr -force 0x40038000 $c 4096
mwr -force 0x4003C000 $c 4096
mwr -force 0x40020000 0x561
after 300
puts "FILLED $c CTRL=[format 0x%X [mrd -force -value 0x40020000]]"
disconnect
