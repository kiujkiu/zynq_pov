# 只点亮 panel 1 (0x40028000/2C000), panel 2 (0x40038000/3C000) 填黑 = 关闭
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561
after 100
# panel 1 = 亮 (白)
mwr -force 0x40028000 0x3F3F3F 4096
mwr -force 0x4002C000 0x3F3F3F 4096
# panel 2 = 黑 (关)
mwr -force 0x40038000 0x000000 4096
mwr -force 0x4003C000 0x000000 4096
puts "PANEL1 = ON (white), PANEL2 = OFF (black)"
after 500
disconnect
