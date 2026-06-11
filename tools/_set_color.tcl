# 用法: xsdb _set_color.tcl <color_hex_BGR>
# 例: xsdb _set_color.tcl 0x00003F00   ; # 纯绿
# 例: xsdb _set_color.tcl 0x003F0000   ; # 纯蓝
# 例: xsdb _set_color.tcl 0x00003F3F   ; # 黄 (R+G)
# 例: xsdb _set_color.tcl 0x003F3F3F   ; # 白
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
set COLOR [lindex $argv 0]
if {$COLOR eq ""} { set COLOR 0x00003F00 }

# 跟 test_solid_no_fb.tcl 同样: mode 0 SOLID, use_fb=0
mwr -force $BASE 0
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}] 127
mwr -force [expr {$BASE + 0x4}]  $COLOR
mwr -force [expr {$BASE + 0x10}] $COLOR
mwr -force $BASE 0x501

after 200
puts "COLOR=$COLOR"
puts "CTRL   [mrd -force $BASE 1]"
puts "STATUS [mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
