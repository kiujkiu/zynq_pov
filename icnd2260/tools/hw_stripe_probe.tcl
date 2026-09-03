# Measure the CHIP'S ACTUAL DISPLAY RATE with pattern mode 7 (frame-phase stripes)
# + a SHORT-EXPOSURE PHOTO.
#
#   40 columns are split into 8 stripes of 5 px. Frame k lights only stripe (k mod 8).
#   Photograph at 1/1000 s:  n stripes lit  =>  display rate ~= n / exposure_time
#   (The naked eye CANNOT read this: under asynchronous sampling the long-term
#    average is identical no matter how many frames the chip actually shows.)
#
# Each point RE-PROGRAMS the device first: reg_rom is RAM, so pokes survive
# soft_rst and would otherwise leak into the next point as a hidden variable.
#
# args: <name> <build_dir> <hold_s> <lvl_hex> <content_clk> <bitclk_hz> <points...>
#   each point = reg00:reg06:target_fps      e.g. 493C:AA44:4000
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set BD   [lindex $argv 1]
set HOLD [lindex $argv 2]
set LVL  [lindex $argv 3]
# 🔴 位时钟必须跟着 bit 走: 写死 62.5MHz 用在 142.9MHz 上会让每个帧率目标都算错。
set HZ [lindex $argv 5]
# 🔴 帧内容随 CASCADE 变: cas1=15268 拍, cas2=29668 拍(=2x14400+868 固定开销)。
#    写死会让每个帧率目标都算错。第 4 个参数传对应值。
set CONTENT [lindex $argv 4]
set PTS [lrange $argv 6 end]
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
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
puts "=== STRIPE PROBE on $NAME.  8 stripes x 5 px.  $HOLD s per point."
puts {===   PHOTOGRAPH each point at 1/1000 s shutter, then COUNT THE LIT STRIPES.}
puts {===   display fps ~= (lit stripes) / (exposure seconds).  Do NOT trust your eyes here.}
set WE 0
foreach pt $PTS {
    lassign [split $pt ":"] r00 r06 tfps
    program_hw_devices $dev
    refresh_hw_device $dev
    after 2000
    set v ""
    for {set t 0} {$t < 6} {incr t} {
        set vs [get_hw_vios]
        if {[llength $vs] > 0} { set v [lindex $vs 0] ; break }
        after 1000 ; refresh_hw_device $dev }
    if {$v eq ""} { puts "=== ABORT: no VIO ===" ; exit 1 }
    set WE 0
    setp $v dbg_pat_mode 7 ; setp $v dbg_pat_lvl $LVL
    setp $v dbg_reg_addr 00 ; setp $v dbg_reg_data $r00
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    setp $v dbg_reg_addr 06 ; setp $v dbg_reg_data $r06
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    set gap [expr {int($HZ/$tfps) - $CONTENT}]
    if {$gap < 1} { set gap 1 }
    setp $v dbg_frame_gap [format %06X $gap]
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 3000
    refresh_hw_vio $v
    set got [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]]
    puts [format "=== %s  reg00=0x%s reg06=0x%s  SENT=%d fps   PHOTOGRAPH NOW (%d s)" \
        [clock format [clock seconds] -format %T] $r00 $r06 $got $HOLD]
    after [expr {$HOLD*1000}]
}
puts "=== done ==="
close_hw_target
exit 0
