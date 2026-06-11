connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "IP0 AP_CTRL @ 0x43C20000: [mrd -value 0x43C20000]"
puts "IP1 AP_CTRL @ 0x40000000: [mrd -value 0x40000000]"
puts "IP2 AP_CTRL @ 0x40010000: [mrd -value 0x40010000]"
puts "IP3 AP_CTRL @ 0x40020000: [mrd -value 0x40020000]"
puts ""
puts "Write 0xDEADBEEF to IP1 num_points (0x4000001c):"
mwr 0x4000001c 0xDEADBEEF
puts "IP1 num_points readback: [mrd -value 0x4000001c]"
con
exit
