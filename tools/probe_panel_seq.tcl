connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
puts "read status (idle=0):"
puts [mrd -force 0x40010000]
puts "write marker LE=20 (cmd=0x140000):"
mwr -force 0x40010000 0x140000
after 10
puts [mrd -force 0x40010000]
puts "write PRE_ACT marker LE=14 (cmd=0xE0000):"
mwr -force 0x40010000 0xE0000
after 1
puts [mrd -force 0x40010000]
puts "write word data=0xAABB LE=5 (cmd=0x5AABB):"
mwr -force 0x40010000 0x5AABB
after 1
puts [mrd -force 0x40010000]
catch { con }
exit 0
