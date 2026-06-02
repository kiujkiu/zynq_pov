# mode 0 SOLID with explicit COLOR top+bot. Args: TUNIT RGB24
if {$argc < 2} {
    puts "usage: set_solid_color.tcl <TUNIT> <RGB24>"
    exit 1
}
set tunit [lindex $argv 0]
set rgb   [lindex $argv 1]
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr 0x40020014 $tunit       ; # TUNIT
mwr 0x40020004 $rgb         ; # COLOR top
mwr 0x40020010 $rgb         ; # COLOR bot
mwr 0x40020000 0x501        ; # CTRL: en=1 mode=0 addr_bits=5
after 200
puts "TUNIT=$tunit RGB=$rgb STATUS=[mrd 0x4002000C]"
exit 0
