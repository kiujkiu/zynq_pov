connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# Ring buffer at 0x12000000, slot 0
puts "=== ring slot 0 first 32 bytes (slice 0) ==="
puts [mrd 0x12000000 8]
puts "=== ring slot 36 first 32 bytes (slice 180° angle) ==="
puts [mrd 0x1214F640 8]
# Count nonzero in slot 18 center area
puts "=== slot 18 center (likely cube/anime densest projection) ==="
puts [mrd 0x120A7B20 8]
exit 0
