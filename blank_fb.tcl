connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
puts "Halt ARM. Writing 0 to fb_A at 0x10000000 (small test 256 bytes)"
# Write 256 words of 0xFFFF0000 = bright pattern
mwr 0x10000000 0xFFFF0000 256
puts "Wrote test pattern. Continue."
con
exit 0
