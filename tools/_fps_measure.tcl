connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
after 200
configparams force-mem-access 1
set s1 [mrd -force -value 0x4002000C]
set t1 [clock milliseconds]
after 2000
set s2 [mrd -force -value 0x4002000C]
set t2 [clock milliseconds]
set f1 [expr {($s1 >> 16) & 0xFFFF}]
set f2 [expr {($s2 >> 16) & 0xFFFF}]
set df [expr {($f2 - $f1) & 0xFFFF}]
set dt [expr {$t2 - $t1}]
puts "frames=$df in ${dt}ms => [expr {$df * 1000 / $dt}] fps"
puts "CTRL=[format 0x%X [mrd -force -value 0x40020000]] TUNIT=[format 0x%X [mrd -force -value 0x40020014]]"
disconnect
