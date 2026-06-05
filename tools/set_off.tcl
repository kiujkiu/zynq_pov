connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr 0x40020000 0
after 100
puts "CTRL=0 STATUS=[mrd 0x4002000C]"
exit 0
