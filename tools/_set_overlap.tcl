connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# clean disable + wait FSM drain
mwr -force 0x40020000 0
after 300
# overlap mode = CTRL 0x561 (bit[6]=1)
mwr -force 0x40020000 0x561
after 200
puts "CTRL = [mrd -force 0x40020000 1]"
puts "STATUS = [mrd -force 0x4002000C 1]"
exit 0
