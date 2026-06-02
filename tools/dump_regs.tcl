connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL    (0x40020000) = [mrd 0x40020000]"
puts "COLOR   (0x40020004) = [mrd 0x40020004]"
puts "PARAM   (0x40020008) = [mrd 0x40020008]"
puts "STATUS  (0x4002000C) = [mrd 0x4002000C]"
puts "COLOR_B (0x40020010) = [mrd 0x40020010]"
puts "TUNIT   (0x40020014) = [mrd 0x40020014]"
exit 0
