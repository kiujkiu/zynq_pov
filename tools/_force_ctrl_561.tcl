# Force panel CTRL = 0x561 (use_fb=1, mode=0, overlap, en) and TUNIT=8
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "CTRL = [mrd -force $BASE 1]"
puts "STATUS = [mrd -force [expr {$BASE + 0xC}] 1]"
puts "TUNIT  = [mrd -force [expr {$BASE + 0x14}] 1]"
exit 0
