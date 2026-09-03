# Program once, then HOLD and sample. No register pokes -- factory table only.
# Question: is the reached state STABLE, or does it keep churning?
# args: <name> <gap_hex> [seconds] [build_dir]
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set SECS 180
if {[llength $argv] > 2} { set SECS [lindex $argv 2] }
set BD "build_dbg"
if {[llength $argv] > 3} { set BD [lindex $argv 3] }
set PMODE ""
if {[llength $argv] > 4} { set PMODE [lindex $argv 4] }
set PLVL 0FFF
if {[llength $argv] > 5} { set PLVL [lindex $argv 5] }
# 第 7 个参数起: "addr:data" 对。用来在不改码值的前提下拉大 LED 电流,
# 解开"要测暗端"和"要看得见"这对矛盾: 0x2d=223F 让红色亮 5.3 倍而量化台阶不变。
set POKES [lrange $argv 6 end]
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
# 🔴 烧录前把这次真正烧进去的产物快照到 build_run_snap/, 否则下一次编译会覆盖构建目录,
#    事后就无法回答"刚才烧的到底是哪张图"(今天栽过两次)。
set SNAP "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_run_snap"
file mkdir $SNAP
foreach e {bit ltx} { catch { file copy -force "$B/$NAME.$e" "$SNAP/" } }
catch { file copy -force "$B/PATTERN.txt" "$SNAP/" }
catch { file copy -force "$B/icnd2260_fb_lvds.mem" "$SNAP/" }
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
setp $v dbg_frame_gap $GAP
if {$PMODE ne ""} { setp $v dbg_pat_mode $PMODE ; setp $v dbg_pat_lvl $PLVL }
set WE 0
foreach pk $POKES {
    set pa [lindex [split $pk ":"] 0] ; set pd [lindex [split $pk ":"] 1]
    setp $v dbg_reg_addr $pa ; setp $v dbg_reg_data $pd
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    puts "===   poke reg\[0x$pa\] = 0x$pd"
}
setp $v g_dbg.o_soft_rst 1 ; after 2000
setp $v g_dbg.o_soft_rst 0
puts "=== WATCH $NAME  gap=0x$GAP  for $SECS s.  ONE power-up, then just hold."
puts "=== Q1: does the bad tile HEAL?   Q2: once good, does it STAY good?"
set n [expr {$SECS/5}]
for {set i 1} {$i <= $n} {incr i} {
    after 5000
    refresh_hw_vio $v
    puts [format "=== %s  t=%3ds  fps=%-4d frame_cnt=0x%s  status=0x%s" \
        [clock format [clock seconds] -format %T] [expr 5*$i] \
        [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [get_property INPUT_VALUE [PX $v frame_cnt]] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}
puts "=== done ==="
close_hw_target
exit 0
