connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "FCLK1 = [mrd -force 0xF8000180 1]"
puts "IO_PLL = [mrd -force 0xF8000108 1]"
puts "STATUS = [mrd -force 0x4002000C 1]"
exit 0
