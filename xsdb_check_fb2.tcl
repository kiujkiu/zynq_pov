connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== fb_A (0x10000000) words 0..11 ==="
set d [mrd 0x10000000 12]
puts $d
puts "=== fb_A center area 0x1014C3C0 ==="
set d [mrd 0x1014C3C0 16]
puts $d
puts "=== fb_B (0x14000000) words 0..11 ==="
set d [mrd 0x14000000 12]
puts $d
puts "=== ring slot0 (0x12000000) ==="
set d [mrd 0x12000000 16]
puts $d
puts "=== ring slot10 (0x12095200) ==="
set d [mrd 0x12095200 16]
puts $d
puts "=== VDMA DMACR 0x43000000 ==="
set d [mrd 0x43000000 1]
puts $d
puts "=== VDMA PARK_PTR_REG 0x43000028 ==="
set d [mrd 0x43000028 1]
puts $d
exit 0
