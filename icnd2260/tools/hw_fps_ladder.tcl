# Frame-rate LADDER: fix the refresh-group count, then walk the sent frame rate up
# one step at a time WITHOUT resetting in between -- so "where does it break" is a
# pure function of frame rate, uncontaminated by power-up reliability.
# args: <name> <build_dir> <reg00_hex> <hold_s> <fps_list_colon_separated> [bitclk_hz] [content_clk]
#   e.g.  ... 493C 8 60:80:100:120:140:160:180:200:220:250
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set BD   [lindex $argv 1]
set R00  [lindex $argv 2]
set HOLD [lindex $argv 3]
set FPSL [split [lindex $argv 4] ":"]
set HZ 62500000
if {[llength $argv] > 5} { set HZ [lindex $argv 5] }
set CONTENT 15270   ;# 🔴 原来是 13907 —— 低于协议硬地板 14400(1800字x8拍), 物理上不可能。
                    ;#    15,270 由 RTL 逐拍数出, 与高速档实测反解的 15,268 差 0.01%
if {[llength $argv] > 6} { set CONTENT [lindex $argv 6] }
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
for {set t 0} {$t < 5} {incr t} {
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
setp $v dbg_pat_mode 0 ; setp $v dbg_pat_lvl 0FFF
# groups + one clean power-up, then never reset again
setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $R00
setp $v g_dbg.o_we_tog 1
set first [lindex $FPSL 0]
setp $v dbg_frame_gap [format %06X [expr {int($HZ/$first) - $CONTENT}]]
setp $v g_dbg.o_soft_rst 1 ; after 2000
setp $v g_dbg.o_soft_rst 0 ; after 3000
puts "=== FPS LADDER on $NAME   reg00=0x$R00   bitclk=$HZ   content=$CONTENT clk"
puts "=== No reset between steps -- only the frame rate changes."
puts {===   At each step: is the image still INTACT? is the gradient still SMOOTH?}
foreach f $FPSL {
    set gap [expr {int($HZ/$f) - $CONTENT}]
    if {$gap < 0} { set gap 0 }
    setp $v dbg_frame_gap [format %06X $gap]
    # 🔴 每档都真正断电重来: 灯板 DCDC 有需要重新上电才恢复的故障(2026-09-02 用户实测),
    #    连续跑多档不断电的话, 后面几档可能是在已经劣化的供电上测的。
    #    原设计刻意不复位是为了把帧率隔离成唯一变量, 但单颗场景下第一颗上电 100% 可靠,
    #    所以断电的代价很小, 而供电干净的收益是实打实的。
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 3000
    after 1500
    refresh_hw_vio $v
    set got [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]
    puts [format "=== %s  target=%5d fps   gap=%7d   MEASURED=%5d fps    LOOK NOW (%d s)" \
        [clock format [clock seconds] -format %T] $f $gap $got $HOLD]
    after [expr {$HOLD*1000}]
}
puts "=== done ==="
close_hw_target
exit 0
