# Set TUNIT for brightness adjustment. Arg: tunit value
if {$argc < 1} { puts "usage: set_tunit.tcl <TUNIT>"; exit 1 }
set tunit [lindex $argv 0]
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr 0x40020014 $tunit
after 200
puts "TUNIT=[mrd 0x40020014]"
exit 0
