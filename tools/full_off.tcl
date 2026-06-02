connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# halt ARM cores so nothing writes registers
targets -set -nocase -filter {name =~ "ARM*#0"}
catch {stop}
targets -set -nocase -filter {name =~ "ARM*#1"}
catch {stop}
targets -set -nocase -filter {name =~ "APU*"}
# clear ctrl+colors
mwr 0x40020000 0
mwr 0x40020004 0
mwr 0x40020010 0
after 500
puts "CTRL=[mrd 0x40020000]  COLOR=[mrd 0x40020004]  STATUS=[mrd 0x4002000C]"
after 1000
puts "STATUS_after_1s=[mrd 0x4002000C]"
exit 0
