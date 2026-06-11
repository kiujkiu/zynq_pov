connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop

puts "Step 1: clear slot 0 to AA"
mwr 0x12000000 0xAAAAAAAA 9540
puts "OK"

puts "Step 2: NUM_POINTS=100 fire"
mwr -force 0x43C2001C 100
mwr -force 0x43C20000 0x1
after 100
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Slot 0 head: [mrd 0x12000000 4]"
puts "Slot 0 row 60: [mrd 0x12004A88 4]"

puts ""
puts "Step 3: NUM_POINTS=1000 fire"
mwr 0x12000000 0xAAAAAAAA 9540
mwr -force 0x43C2001C 1000
mwr -force 0x43C20000 0x1
after 200
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Slot 0 head: [mrd 0x12000000 4]"
puts "Slot 0 row 60: [mrd 0x12004A88 4]"

puts ""
puts "Step 4: NUM_POINTS=30803 fire"
mwr 0x12000000 0xAAAAAAAA 9540
mwr -force 0x43C2001C 30803
mwr -force 0x43C20000 0x1
after 500
puts "AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Slot 0 head: [mrd 0x12000000 4]"
puts "Slot 0 row 60: [mrd 0x12004A88 4]"

con
exit 0
