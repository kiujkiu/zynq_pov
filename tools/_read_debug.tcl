connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
puts "STATUS = [mrd -force [expr {$BASE + 0x0C}] 1]"
puts "CTRL   = [mrd -force [expr {$BASE + 0x00}] 1]"
puts "COLOR  = [mrd -force [expr {$BASE + 0x04}] 1]"
puts "TUNIT  = [mrd -force [expr {$BASE + 0x14}] 1]"
exit 0
