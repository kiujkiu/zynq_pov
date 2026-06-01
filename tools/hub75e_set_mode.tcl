# Usage: xsdb hub75e_set_mode.tcl <mode> [addr_mode_sr=0]
# mode: 0=SOLID 1=HSTRIPE 2=VSTRIPE 3=CHECKER 4=ROWWALK 5=COLWALK 6=GRAD 7=WHITE
connect
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

set mode [lindex $argv 0]
set sr 0
if {[llength $argv] >= 2} { set sr [lindex $argv 1] }

# enable + mode + addr_mode + 5-bit scan
set ctrl [expr {0x01 | (($mode & 0x7) << 1) | (($sr & 0x1) << 4) | (5 << 8)}]
puts "writing CTRL = [format 0x%08x $ctrl]  (mode=$mode addr_sr=$sr scan=1/32)"
mwr 0x40020000 $ctrl
after 200
puts "STATUS = [format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
