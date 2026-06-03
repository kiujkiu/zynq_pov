connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x561
puts "HUB75E re-enabled CTRL=[mrd -force 0x40020000 1]"
exit 0
