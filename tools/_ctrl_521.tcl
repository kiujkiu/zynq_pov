connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x521
after 300
puts "CTRL=[mrd -force 0x40020000 1]"
disconnect
