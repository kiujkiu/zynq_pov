connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# Slot 0 - full 256 bytes (cube would show projection)
puts "=== slot 0 first 64 words (256 bytes) ==="
puts [mrd 0x12000000 64]
# Count nonzero bytes in whole ring buffer
puts "=== nonzero scan: dump 100 widely-spaced words ==="
for {set i 0} {$i < 72} {incr i 9} {
    set addr [expr {0x12000000 + $i * 38160 + 19000}]
    set fmt [format "slot %d @ 0x%x:" $i $addr]
    puts "$fmt"
    puts [mrd $addr 4]
}
exit 0
