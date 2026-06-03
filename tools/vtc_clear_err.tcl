connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "before: CTRL=[mrd -force 0x43C00000 1] ERROR=[mrd -force 0x43C00010 1]"
# Clear ERROR (RW1C — write 1 to clear)
mwr -force 0x43C00010 0xFFFFFFFF
# SW reset, then re-enable
mwr -force 0x43C00000 0x80000000
after 50
mwr -force 0x43C00000 0x00000005
after 100
puts "after:  CTRL=[mrd -force 0x43C00000 1] ERROR=[mrd -force 0x43C00010 1]"
puts "STATUS (0x024)=[mrd -force 0x43C00024 1]  ACTIVE (0x068)=[mrd -force 0x43C00068 1]"
exit 0
