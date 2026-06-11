connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== fb_A row 0 (dy=0): line should have dx pattern at col 0..3 ==="
puts [mrd 0x10000000 8]
puts "=== fb_A row 100 col 500 (0x10000000 + 100*3840 + 500*3 = 0x1005F5DC) ==="
puts [mrd 0x1005F5DC 8]
puts "=== fb_B row 0 col 0 ==="
puts [mrd 0x14000000 8]
puts "=== fb_B row 360 col 640 (0x14000000 + 360*3840 + 640*3 = 0x1414C780) ==="
puts [mrd 0x1414C780 8]
exit 0
