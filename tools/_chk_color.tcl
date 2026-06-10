connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL    = [mrd -force 0x40020000 1]"
puts "COLOR   = [mrd -force 0x40020004 1]"
puts "PARAM   = [mrd -force 0x40020008 1]"
puts "STATUS  = [mrd -force 0x4002000C 1]"
puts "COLORB  = [mrd -force 0x40020010 1]"
puts "TUNIT   = [mrd -force 0x40020014 1]"
exit 0
