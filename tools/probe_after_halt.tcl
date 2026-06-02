connect
after 200
targets
puts "--- targets above ---"
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL_before=[mrd 0x40020000]"
mwr 0x40020014 8
mwr 0x40020004 0x3F3F3F
mwr 0x40020010 0x3F3F3F
mwr 0x40020000 0x50F
after 500
puts "CTRL_after=[mrd 0x40020000]"
puts "COLOR=[mrd 0x40020004]"
puts "TUNIT=[mrd 0x40020014]"
puts "STATUS=[mrd 0x4002000C]"
# resume ARM if halted
catch {targets -set -nocase -filter {name =~ "ARM*#0"}; con}
catch {targets -set -nocase -filter {name =~ "ARM*#1"}; con}
exit 0
