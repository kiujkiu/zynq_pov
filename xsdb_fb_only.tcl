connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== fb_A row 0 col 322 (top of slice) ==="
puts [mrd 0x100003C0 8]
puts "=== fb_A row 360 col 322 (mid of slice) ==="
puts [mrd 0x1014C3C0 8]
puts "=== fb_B row 0 col 322 ==="
puts [mrd 0x140003C0 8]
puts "=== fb_B row 360 col 322 ==="
puts [mrd 0x1414C3C0 8]
puts "=== fb_A row 0 col 0 (left bezel, should be black) ==="
puts [mrd 0x10000000 4]
puts "=== fb_A row 0 col 1000 (right bezel, black) 0x10000000 + 1000*3 = 0x10000BB8 ==="
puts [mrd 0x10000BB8 4]
puts "=== ring buffer scan: which slot has nonzero data? ==="
for {set s 0} {$s < 72} {incr s 6} {
    set addr [expr 0x12000000 + $s * 38160]
    set hex [format "0x%08x" $addr]
    set first [mrd $addr 1]
    set mid_addr [expr $addr + 19080]
    set mid [mrd $mid_addr 1]
    puts "slot $s @ $hex: head=$first mid=$mid"
}
exit 0
