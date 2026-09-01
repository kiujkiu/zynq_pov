# hw_try_dclk.tcl -- 对照 DCLK=0 / DCLK=1 两种情况
#
# 假设: DCLK 在 mini-LVDS 模式下可能是模式/使能 strap。
# 每轮都软复位重跑上电流程, 让 DCLK 电平在灯板上电那一刻就已就位。
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROGRAM.FILE "$B/$NAME.bit" $dev
set_property PROBES.FILE "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
after 2000
set v [lindex [get_hw_vios] 0]
proc P {v pat} {
    foreach p [get_hw_probes -of_objects $v] {
        if {[string match $pat [get_property NAME $p]]} { return $p }
    }
    return ""
}
set p_dclk [P $v "*dclk_lvl*"]
set p_rst  [P $v "*soft_rst*"]
set p_cnt  [P $v "*ack_frame_cnt*"]
set p_err  [P $v "*ack_err_cnt*"]
set p_stat [P $v "*status*"]
set p_fps  [P $v "*fps_latched*"]
if {$p_dclk eq ""} { puts "=== 找不到 dclk_lvl 探针 ==="; exit 1 }

foreach lvl {0 1} {
    set_property OUTPUT_VALUE $lvl $p_dclk
    commit_hw_vio $p_dclk
    # 软复位: 电源关再开, 让 DCLK 电平在灯板上电时就位
    set_property OUTPUT_VALUE 1 $p_rst; commit_hw_vio $p_rst; after 300
    set_property OUTPUT_VALUE 0 $p_rst; commit_hw_vio $p_rst
    after 2500
    refresh_hw_vio $v
    set c0 [expr 0x[get_property INPUT_VALUE $p_cnt]]
    set e0 [expr 0x[get_property INPUT_VALUE $p_err]]
    after 1500
    refresh_hw_vio $v
    set c1 [expr 0x[get_property INPUT_VALUE $p_cnt]]
    set e1 [expr 0x[get_property INPUT_VALUE $p_err]]
    puts [format "=== DCLK=%s : fps=%s status=%s  CRC通过增量=%d 错误增量=%d" \
          $lvl [get_property INPUT_VALUE $p_fps] [get_property INPUT_VALUE $p_stat] \
          [expr {($c1-$c0)&0xFFFF}] [expr {($e1-$e0)&0xFFFF}]]
}
puts "=== 现在停在 DCLK=1, 去看屏 / 摸芯片温度 ==="
close_hw_target
