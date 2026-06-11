connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
# Clear ring slot 0 to known value
puts "Step 1: clear slot 0 (38160 bytes) to 0xAA"
mwr 0x12000000 0xAAAAAAAA 9540

# Verify clear
puts "Slot 0 head after clear: [mrd 0x12000000 4]"
puts "Slot 0 mid after clear: [mrd 0x1200CC60 4]"

# Now fire HLS with current registers (anime model, 30803 points)
puts ""
puts "Step 2: fire HLS"
mwr -force 0x43C20000 0x1
after 200
puts "AP_CTRL after 200ms: [mrd -force 0x43C20000 1]"

# Read ring slot 0 to see what HLS wrote
puts "Slot 0 head after HLS: [mrd 0x12000000 8]"
puts "Slot 0 mid after HLS (row 60): [mrd 0x12004A88 8]"
puts "Slot 0 near end (row 100): [mrd 0x12007C30 8]"

con
exit 0
