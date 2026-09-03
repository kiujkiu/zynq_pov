# 色深 A/B: 数斜坡起点有几颗 LED 全黑 = 量化台阶 = 位深。
#   量化台阶 Q ⇒ 码值 0..Q-1 全部量化成 0 ⇒ 开头 Q 颗全黑。
#   74 分组(14.2位) Q=3.5 -> 开头 3~4 颗黑;  16 分组(12.0位) Q=16 -> 开头 16 颗黑。
# "亮/不亮"是二值判断, 不怕饱和/曝光/透视/裁剪 —— 这是手机唯一能胜任的读法。
# args: <name> <build_dir> <hold_s>
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set BD   [lindex $argv 1]
set HOLD [lindex $argv 2]
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROGRAM.FILE     "$B/$NAME.bit" $dev
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
after 2000
set v ""
for {set t 0} {$t < 6} {incr t} {
    set vs [get_hw_vios]
    if {[llength $vs] > 0} { set v [lindex $vs 0] ; break }
    after 1000 ; refresh_hw_device $dev }
if {$v eq ""} { puts "=== ABORT: no VIO ===" ; exit 1 }
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
setp $v dbg_frame_gap 0186A0
setp $v dbg_pat_mode 0 ; setp $v dbg_pat_lvl 0FFF
set WE 0
# 红色电流拉满, 让极暗的头几级也看得见
setp $v dbg_reg_addr 2d ; setp $v dbg_reg_data 223F
set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
puts "=== DEPTH A/B: count how many LEDs at the ramp origin are COMPLETELY DARK."
puts {===   74 groups (14.2 bit): quantum 3.5 codes -> about 3~4 dark}
puts {===   16 groups (12.0 bit): quantum  16 codes -> about 16 dark}
foreach pt {493C 0F3C} {
    setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $pt
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 3000
    # 🔴 别在 expr 里拼 "0x$pt", Tcl 解析不了; 先 scan 成整数再算(同类坑见记忆库)
    set gv 0 ; scan $pt %x gv
    set grp [expr {($gv >> 8) + 1}]
    puts [format "=== %s  reg00=0x%s  %d groups   COUNT DARK LEDs NOW (%d s)" \
        [clock format [clock seconds] -format %T] $pt $grp $HOLD]
    after [expr {$HOLD*1000}]
}
puts "=== done ==="
close_hw_target
exit 0
