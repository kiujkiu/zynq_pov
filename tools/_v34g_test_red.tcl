connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000008
mwr -force [expr {$BASE + 0x8}]  127
mwr -force [expr {$BASE + 0x4}]  0x00000010 ; # TOP RED dim
mwr -force [expr {$BASE + 0x10}] 0x00000010 ; # BOT RED dim
mwr -force $BASE 0x501  ; # use_fb=0 SOLID
after 200
puts "v34g SOLID RED CTRL=[mrd -force $BASE 1]"
exit 0
