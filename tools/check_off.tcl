connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "BEFORE: CTRL=[mrd 0x40020000]  STATUS=[mrd 0x4002000C]"
mwr 0x40020000 0
after 500
puts "AFTER1: CTRL=[mrd 0x40020000]  STATUS=[mrd 0x4002000C]"
after 1000
puts "AFTER2: CTRL=[mrd 0x40020000]  STATUS=[mrd 0x4002000C]"
after 2000
puts "AFTER3: CTRL=[mrd 0x40020000]  STATUS=[mrd 0x4002000C]"
exit 0
