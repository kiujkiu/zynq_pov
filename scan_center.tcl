connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== fb_A scan rows at col 600 (center of slice) ==="
foreach row {0 100 200 300 360 400 500 600 700} {
    set off [expr {$row * 3840 + 600 * 3}]
    set addr [expr {0x10000000 + $off}]
    puts [format "row %d col 600 @ 0x%x:" $row $addr]
    puts [mrd $addr 4]
}
exit 0
