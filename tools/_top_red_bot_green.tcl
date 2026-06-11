connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
mwr -force $BASE 0
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}]  127
mwr -force [expr {$BASE + 0x4}]  0x00000010  ; # TOP = RED dim
mwr -force [expr {$BASE + 0x10}] 0x00001000  ; # BOT = GREEN dim
mwr -force $BASE 0x501
after 200
puts "TOP=RED, BOT=GREEN  CTRL [mrd -force $BASE 1]"
exit 0
