# Set one PL register and exit, used to drive xsdb from shell loop.
# Args: TUNIT CTRL  (decimals/hex both OK)
if {$argc < 2} {
    puts "usage: xsdb set_one_mode.tcl <TUNIT> <CTRL>"
    exit 1
}
set tunit [lindex $argv 0]
set ctrl  [lindex $argv 1]
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr 0x40020014 $tunit
mwr 0x40020000 $ctrl
after 200
puts "TUNIT=$tunit CTRL=$ctrl  STATUS=[mrd 0x4002000C]"
exit 0
