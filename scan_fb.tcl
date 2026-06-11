connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
puts "=== fb_A scan rows 0,100,300,500,700 ==="
foreach row {0 100 300 500 700} {
    set off [expr {$row * 3840}]
    set addr [expr {0x10000000 + $off}]
    set fmt [format "row %d @ 0x%x: " $row $addr]
    puts "$fmt"
    puts [mrd $addr 4]
}
puts ""
puts "=== fb_B scan rows 0,100,300,500,700 ==="
foreach row {0 100 300 500 700} {
    set off [expr {$row * 3840}]
    set addr [expr {0x14000000 + $off}]
    set fmt [format "row %d @ 0x%x: " $row $addr]
    puts "$fmt"
    puts [mrd $addr 4]
}
con
exit 0
