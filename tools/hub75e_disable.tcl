connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "before: HUB75E CTRL = [mrd -force 0x40020000 1]"
puts "        VDMA SR    = [mrd -force 0x43C10004 1]"
mwr -force 0x40020000 0
after 500
puts "after:  HUB75E CTRL = [mrd -force 0x40020000 1]"
puts "        VDMA SR    = [mrd -force 0x43C10004 1]"
puts "        VDMA park  = [mrd -force 0x43C10028 1]"
exit 0
