connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
for {set i 0} {$i < 15} {incr i} {
    set c [mrd -force -value 0x40020000]
    if {$c != 0} { break }
    after 1000
}
puts "CTRL=[format 0x%X $c] after ${i}s"
if {$c != 0} {
    set s1 [mrd -force -value 0x4002000C]
    after 2000
    set s2 [mrd -force -value 0x4002000C]
    set df [expr {(($s2 >> 16) - ($s1 >> 16)) & 0xFFFF}]
    puts "frames=$df in 2s => [expr {$df / 2}] fps"
    puts "TUNIT=[format 0x%X [mrd -force -value 0x40020014]]"
}
disconnect
