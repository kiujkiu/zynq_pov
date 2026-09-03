# Measure the CHIP'S DISPLAY RATE.  Pattern mode 7 = frame-phase stripes:
# 40 columns / 8 stripes of 5 px; frame k lights only stripe (k mod 8).
# Read it with a SHORT-EXPOSURE PHOTO -- the naked eye is blind here, because
# under asynchronous sampling the long-term average is identical regardless of
# how many frames the chip actually shows.
#     lit stripes n at exposure T  =>  display rate ~= n / T
# Self-checks first: mode 5 must be FULL WHITE, mode 6 must be ALL BLACK.
# If either fails, mode 7 cannot be trusted (an unimplemented mode falls through
# to the same all-black default and would read as "chip showed zero frames").
# args: <name> <build_dir> <content_clk> <fps_list_colon_sep> <hold_s>
# 🔴 判读不需要知道快门: 捕获条数 = 显示帧率 x 曝光时间, 曝光固定 =>
#    条数随发送帧率**成正比上升** = 芯片跟得上; **升到某档不涨了** = 那就是芯片显示上限。
#    曝光时间在比值里被约掉。
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set BD   [lindex $argv 1]
set CONTENT [lindex $argv 2]
set FPSL [split [lindex $argv 3] ":"]
set HOLD [lindex $argv 4]
set HZ 62500000
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
setp $v dbg_pat_lvl 3FFF
setp $v dbg_frame_gap [format %06X [expr {int($HZ/[lindex $FPSL 0]) - $CONTENT}]]
setp $v g_dbg.o_soft_rst 1 ; after 2000
setp $v g_dbg.o_soft_rst 0 ; after 3000
puts "=== SELF-CHECK 1/2: mode 5 = FULL WHITE for 10 s.  If it is not white, STOP."
setp $v dbg_pat_mode 5 ; after 10000
puts "=== SELF-CHECK 2/2: mode 6 = ALL BLACK for 10 s.  If it is not black, STOP."
setp $v dbg_pat_mode 6 ; after 10000
refresh_hw_vio $v
set got [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]
puts "=== SELF-CHECKS DONE. MODE 7 (8 stripes) now, sweeping the send rate."
puts {===   Shoot at 1/100, 1/500, 1/1000, 1/2000, 1/4000 s.  Count the LIT stripes each time.}
puts {===   display fps ~= lit_stripes / exposure_seconds.   DO NOT judge by eye.}
setp $v dbg_pat_mode 7
foreach f $FPSL {
    set gap [expr {int($HZ/$f) - $CONTENT}]
    if {$gap < 1} { set gap 1 }
    setp $v dbg_frame_gap [format %06X $gap]
    # 🔴 每档都真正断电重来: 灯板 DCDC 有需要重新上电才恢复的故障(2026-09-02 用户实测),
    #    连续跑多档不断电的话, 后面几档可能是在已经劣化的供电上测的。
    #    原设计刻意不复位是为了把帧率隔离成唯一变量, 但单颗场景下第一颗上电 100% 可靠,
    #    所以断电的代价很小, 而供电干净的收益是实打实的。
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 3000
    # 🔴 fps_latched 是 1 秒窗口计数器: 改完 gap 必须等窗口整个走完再读,
    #    否则读到跨越变更点的半个窗口(实测 1.5s 时 1000 档读成 839)。等 2.5s 并读两次取后者。
    after 2500 ; refresh_hw_vio $v ; after 1200 ; refresh_hw_vio $v
    set got [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]
    puts [format "=== %s  SENT=%5d fps (target %5d)   RECORD SLO-MO NOW (%d s)" \
        [clock format [clock seconds] -format %T] $got $f $HOLD]
    after [expr {$HOLD*1000}]
}
puts "=== done ==="
close_hw_target
exit 0
