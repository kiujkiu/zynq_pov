connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 50
mwr -force [expr {$BASE + 0x4}]  0x00003F00  ; # TOP COLOR = pure GREEN (G=0x3F max)
mwr -force [expr {$BASE + 0x10}] 0x00003F00  ; # BOT COLOR = pure GREEN
mwr -force [expr {$BASE + 0x14}] 0x00000008  ; # TUNIT=8
mwr -force [expr {$BASE + 0x8}]  127         ; # width_max
mwr -force $BASE 0x501                       ; # en + mode 0 SOLID, use_fb=0
after 200
puts "CTRL=[mrd -force $BASE 1] TOP_COLOR=[mrd -force [expr {$BASE + 4}] 1] STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
puts "panel should be SOLID GREEN"
exit 0
