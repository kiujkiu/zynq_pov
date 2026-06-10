connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# Disable panel first so reads aren't moving
mwr -force 0x40020000 0
after 100
puts "=== single write/read test ==="
mwr -force 0x40028000 0xDEADBEEF
after 50
puts "after wr 0xDEADBEEF: [mrd -force 0x40028000 1]"
mwr -force 0x40028004 0xCAFEBABE
after 50
puts "after wr 0xCAFEBABE @+4: [mrd -force 0x40028004 1]"
puts "re-read @0x40028000: [mrd -force 0x40028000 1]"
puts "=== CTRL/TUNIT readback ==="
puts "CTRL  @0x40020000 = [mrd -force 0x40020000 1]"
puts "TUNIT @0x40020014 = [mrd -force 0x40020014 1]"
exit 0
