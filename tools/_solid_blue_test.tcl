connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
# TUNIT explicit: [11:8]=6 BCM planes, [7:0]=8 TUNIT
mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x4}]  0x003F0000  ; # TOP COLOR = BLUE (B=0x3F)
mwr -force [expr {$BASE + 0x10}] 0x003F0000  ; # BOT COLOR = BLUE
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x501
after 200
puts "CTRL=[mrd -force $BASE 1] TOP_COLOR=[mrd -force [expr {$BASE + 4}] 1] TUNIT=[mrd -force [expr {$BASE + 0x14}] 1]"
exit 0
