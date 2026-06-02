# v28: set mode 0 SOLID with explicit COLOR + overlap_en. Args: TUNIT RGB24 OVERLAP_EN
if {$argc < 3} {
    puts "usage: set_solid_v28.tcl <TUNIT> <RGB24> <OVERLAP_EN 0|1>"
    exit 1
}
set tunit   [lindex $argv 0]
set rgb     [lindex $argv 1]
set overlap [lindex $argv 2]
# CTRL = en(1) | mode0<<1 | addr_bits=5<<8 | overlap<<6 = 0x501 + ($overlap*0x40)
set ctrl [expr {0x501 | ($overlap * 0x40)}]
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr 0x40020014 $tunit
mwr 0x40020004 $rgb
mwr 0x40020010 $rgb
mwr 0x40020000 $ctrl
after 200
puts "TUNIT=$tunit RGB=$rgb CTRL=[format 0x%x $ctrl] STATUS=[mrd 0x4002000C]"
exit 0
