connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# disable
mwr -force 0x40020000 0
after 50
# fclk
mwr -force 0xF8000180 0x00500500
after 50
# TUNIT = 0x608
mwr -force 0x40020014 0x00000608
# PLNS = 127
mwr -force 0x40020008 127
# reg_color (offset 0x4) = white 0x3F3F3F
mwr -force 0x40020004 0x003F3F3F
# reg_color_bot (offset 0x10) = white
mwr -force 0x40020010 0x003F3F3F
# CTRL = 0x501 (enable + use_fb=0 + test_mode=0 LUT user_color)
mwr -force 0x40020000 0x00000501
after 200
puts "CTRL set 0x501 (LUT mode white)"
exit 0
