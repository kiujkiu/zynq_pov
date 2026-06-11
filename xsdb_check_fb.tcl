connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== fb_A (0x10000000) byte 0..47 ==="
mrd -size b 0x10000000 48
puts "=== fb_A center row 360, mid col (0x10000000 + 360*3840 + 322*3) = 0x1014C3C6 ==="
mrd -size b 0x1014C3C6 48
puts "=== fb_B (0x14000000) byte 0..47 ==="
mrd -size b 0x14000000 48
puts "=== ring buffer slot0 (0x12000000) byte 0..47 ==="
mrd -size b 0x12000000 48
puts "=== ring buffer slot10 (0x12000000 + 10*38160 = 0x12095200) ==="
mrd -size b 0x12095200 48
exit 0
