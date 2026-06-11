connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020014 0x108
after 300
set s1 [mrd -force -value 0x4002000C]
after 2000
set s2 [mrd -force -value 0x4002000C]
set df [expr {(($s2 >> 16) - ($s1 >> 16)) & 0xFFFF}]
puts "TUNIT=0x108 (1-bit): frames=$df in 2s => [expr {$df / 2}] fps"
disconnect
