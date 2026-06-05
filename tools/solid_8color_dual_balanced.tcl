# v34b dual panel 8 色, 补偿 R/G/B 亮度不均 (R=0x05, G=0x1E, B=0x3F)
# FM6124 LED 物理 R>>G>>B, 软件平衡比例 ~ R×0.35 G×0.9 B×1.3 → R=5/G=28/B=63 of 63
connect
after 300
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
mwr -force 0xF8000180 0x00500500
after 200
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}] 127
mwr -force $BASE 0x561
after 200

# R=0x05, G=0x1C, B=0x3F  (R 弱, G 中, B 满)
set R 0x05
set G 0x1C
set B 0x3F
set RGB_R     [expr {$R}]
set RGB_G     [expr {$G << 8}]
set RGB_B     [expr {$B << 16}]
set RGB_RG    [expr {$RGB_R | $RGB_G}]
set RGB_RB    [expr {$RGB_R | $RGB_B}]
set RGB_GB    [expr {$RGB_G | $RGB_B}]
set RGB_RGB   [expr {$RGB_R | $RGB_G | $RGB_B}]

set colors [list \
    [list $RGB_R   RED] \
    [list $RGB_G   GREEN] \
    [list $RGB_B   BLUE] \
    [list $RGB_RG  YELLOW] \
    [list $RGB_RB  MAGENTA] \
    [list $RGB_GB  CYAN] \
    [list $RGB_RGB WHITE] \
    [list 0        BLACK]]

for {set loop 0} {$loop < 4} {incr loop} {
    foreach pair $colors {
        set color [lindex $pair 0]
        set name  [lindex $pair 1]
        mwr -force [expr {$BASE + 0x4}] $color
        mwr -force [expr {$BASE + 0x10}] $color
        puts "=> $name 0x[format %06x $color]"
        after 4000
    }
}
puts "DONE 4 loops"
exit 0
