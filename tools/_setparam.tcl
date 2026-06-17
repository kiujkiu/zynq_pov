# 现场写 PARAM (含 col_shift), 不重烧. 用法: xsct _setparam.tcl <width_minus1> <col_shift>
set w [lindex $argv 0]; set sh [lindex $argv 1]
set param [expr {($w & 0xFFF) | (($sh & 0xF) << 12)}]
connect
after 500
targets -set -nocase -filter {name =~ "*Cortex*#0*" || name =~ "ARM*#0"}
configparams force-mem-access 1
mwr -force 0x40020008 $param
after 100
puts "PARAM=[format 0x%X [mrd -force -value 0x40020008]] (width-1=$w col_shift=$sh)"
exit
