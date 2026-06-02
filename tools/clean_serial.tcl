# Clean state transition: disable → IDLE → enable new mode
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# disable PL fully to drain FSM to IDLE
mwr 0x40020000 0
after 200
mwr 0x40020004 0x3F3F3F   ; # set bright color
mwr 0x40020010 0x3F3F3F
mwr 0x40020014 32
after 100
# enable SERIAL mode 0 SOLID use_fb=0 overlap_en=0
mwr 0x40020000 0x501
after 500
puts "CLEAN-SERIAL CTRL=[mrd 0x40020000] STATUS=[mrd 0x4002000C]"
exit 0
