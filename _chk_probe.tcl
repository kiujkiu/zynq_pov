connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL=[mrd -force 0x40020000 1]"
puts "STATUS=[mrd -force 0x4002000C 1]"
