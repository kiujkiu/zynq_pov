connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
puts "Test 1: write NUM_POINTS=100, fire HLS"
mwr -force 0x43C2001c 100
mwr -force 0x43C20000 0x1
after 100
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Ring slot 0 first 8 words:"
puts [mrd 0x12000000 8]

puts ""
puts "Test 2: write NUM_POINTS=300, fire HLS"
mwr -force 0x43C2001c 300
mwr -force 0x43C20000 0x1
after 100
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Ring slot 0 first 8 words:"
puts [mrd 0x12000000 8]

puts ""
puts "Test 3: write NUM_POINTS=1000, fire HLS"
mwr -force 0x43C2001c 1000
mwr -force 0x43C20000 0x1
after 100
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Ring slot 0 first 8 words:"
puts [mrd 0x12000000 8]

puts ""
puts "Test 4: write NUM_POINTS=10000, fire HLS"
mwr -force 0x43C2001c 10000
mwr -force 0x43C20000 0x1
after 200
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Ring slot 0 first 8 words:"
puts [mrd 0x12000000 8]

con
exit 0
