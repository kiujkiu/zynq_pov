connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561
after 100
# panel 1 = 50% (0x1F1F1F)
mwr -force 0x40028000 0x1F1F1F 4096
mwr -force 0x4002C000 0x1F1F1F 4096
# panel 2 = 黑
mwr -force 0x40038000 0x000000 4096
mwr -force 0x4003C000 0x000000 4096
puts "PANEL1 = 50% (0x1F), PANEL2 = OFF"
after 500
disconnect
