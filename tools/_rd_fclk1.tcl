connect
after 100
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "FCLK1 [mrd -force 0xF8000180 1]"
puts "FCLK0 [mrd -force 0xF8000170 1]"
puts "ARM_PLL [mrd -force 0xF8000100 1]"
puts "IO_PLL  [mrd -force 0xF8000108 1]"
puts "DDR_PLL [mrd -force 0xF8000104 1]"
exit 0
