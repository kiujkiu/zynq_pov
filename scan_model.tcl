connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# Read 4 points from middle (15000 * 16 = 240000 = 0x3A980)
puts "=== model point 15000 (0x1A03A980) ==="
puts [mrd 0x1A03A980 4]
# End of anime data 30802 * 16 = 0x78110
puts "=== model point 30802 (0x1A078110) ==="
puts [mrd 0x1A078110 4]
# Just past end (should be 0 or old data)
puts "=== past anime data 30803 * 16 = 0x78120 ==="
puts [mrd 0x1A078120 4]
exit 0
