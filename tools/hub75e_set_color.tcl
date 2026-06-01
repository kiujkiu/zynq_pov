# Usage: xsdb hub75e_set_color.tcl <color_hex>
# color: bit[0]=R1 bit[1]=G1 bit[2]=B1 bit[3]=R2 bit[4]=G2 bit[5]=B2
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
set color [lindex $argv 0]
mwr 0x40020004 $color
# mode 0 = SOLID, enable, ABCDE
mwr 0x40020000 0x00000501
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] COLOR=[format 0x%02x [mrd -value 0x40020004]]"
disconnect
exit 0
