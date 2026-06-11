connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL=[format 0x%X [mrd -force -value 0x40020000]]"
puts "TUNIT=[format 0x%X [mrd -force -value 0x40020014]]"
set s1 [mrd -force -value 0x4002000C]
after 1000
set s2 [mrd -force -value 0x4002000C]
puts "frame_delta_1s=[expr {(($s2>>16)-($s1>>16)) & 0xFFFF}]"
puts "BRAM_TOP1_w0=[format 0x%X [mrd -force -value 0x40028000]]"
puts "BRAM_TOP1_w100=[format 0x%X [mrd -force -value 0x40028190]]"
puts "BRAM_TOP2_w100=[format 0x%X [mrd -force -value 0x40038190]]"
# ARM PC (是否活着)
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { puts "ARM0: [targets -filter {name =~ \"ARM*#0\"}]" }
disconnect
