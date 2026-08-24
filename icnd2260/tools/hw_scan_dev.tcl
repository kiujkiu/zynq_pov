# hw_scan_dev.tcl -- 扫 DEVICE 0..15, 看哪几颗芯片应答
#
# 用途: LED 板是黑盒(供应商样板, 拿不到图纸)时, 用这个反推
#       「板上级联了几颗 2260 / 它们的设备号是多少 / 到底活没活」。
#
# 原理: 手册的读寄存器是「读指定设备」, 不支持广播。逐个点名 0..15,
#       谁应答就说明谁在。同时读回它返回的寄存器值, 能进一步确认不是噪声。
#
# 跑法: vivado -mode batch -source tools\hw_scan_dev.tcl -tclargs <bit名>

set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
if {[llength $argv] > 0} { set NAME [lindex $argv 0] }

open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]

set_property PROGRAM.FILE      "$B/$NAME.bit" $dev
set_property PROBES.FILE       "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE  "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
puts "=== 已下载 $NAME ==="
after 2000

set v [lindex [get_hw_vios] 0]

# 按网络名找探针 (Vivado 是用连到 VIO 的网络名给探针命名的)
proc P {v pat} {
    foreach p [get_hw_probes -of_objects $v] {
        if {[string match $pat [get_property NAME $p]]} { return $p }
    }
    return ""
}
set p_dev   [P $v "*probe_dev*"]
set p_min   [P $v "*minimal*"]
set p_en    [P $v "*probe_en*"]
set p_cnt   [P $v "*ack_frame_cnt*"]
set p_err   [P $v "*ack_err_cnt*"]
set p_data  [P $v "*ack_f_data0*"]
set p_fdev  [P $v "*ack_f_dev*"]
set p_stat  [P $v "*status*"]
set p_fps   [P $v "*fps_latched*"]

if {$p_dev eq "" || $p_en eq ""} {
    puts "=== 找不到 probe_dev / probe_en 探针, 列出全部: ==="
    foreach p [get_hw_probes -of_objects $v] { puts "===   [get_property NAME $p]" }
    exit 1
}

refresh_hw_vio $v
puts "=== 基线: fps=[get_property INPUT_VALUE $p_fps] status=[get_property INPUT_VALUE $p_stat] ==="

# 打开覆盖使能
set_property OUTPUT_VALUE 1 $p_en
commit_hw_vio $p_en

puts "=== 绑定的探针 ==="
foreach {n p} [list dev $p_dev en $p_en cnt $p_cnt err $p_err data $p_data fdev $p_fdev] {
    puts "===   $n -> [get_property NAME $p]"
}

# ⚠ 计数器只由复位清零, 所以要用**差值**, 不能看绝对值。
# ⚠ ack_frame_cnt 现在只数 **CRC 通过** 的帧 —— 头部码那道闸挡不住周期性噪声。
proc scan_all {v p_dev p_cnt p_err p_data p_fdev} {
    set found {}
    for {set d 0} {$d < 16} {incr d} {
        set_property OUTPUT_VALUE [format %X $d] $p_dev
        commit_hw_vio $p_dev
        refresh_hw_vio $v
        set c0 [expr 0x[get_property INPUT_VALUE $p_cnt]]
        set e0 [expr 0x[get_property INPUT_VALUE $p_err]]
        after 800
        refresh_hw_vio $v
        set c1 [expr 0x[get_property INPUT_VALUE $p_cnt]]
        set e1 [expr 0x[get_property INPUT_VALUE $p_err]]
        set dc [expr {($c1 - $c0) & 0xFFFF}]
        set de [expr {($e1 - $e0) & 0xFFFF}]
        puts [format "===  dev %2d : CRC通过=%-5d 错误=%-5d  data0=%s  回包dev=%s" \
              $d $dc $de [get_property INPUT_VALUE $p_data] [get_property INPUT_VALUE $p_fdev]]
        if {$dc > 0} { lappend found $d }
    }
    return $found
}

foreach {tag minval} {正常模式 0 最小配置模式 1} {
    if {$p_min ne ""} { set_property OUTPUT_VALUE $minval $p_min; commit_hw_vio $p_min }
    # 切模式后软复位, 让上电流程按新模式重跑
    set p_rst [P $v "*soft_rst*"]
    if {$p_rst ne ""} {
        set_property OUTPUT_VALUE 1 $p_rst; commit_hw_vio $p_rst; after 100
        set_property OUTPUT_VALUE 0 $p_rst; commit_hw_vio $p_rst; after 500
    }
    refresh_hw_vio $v
    puts "=== ===== $tag  (fps=[get_property INPUT_VALUE $p_fps] status=[get_property INPUT_VALUE $p_stat]) ====="
    set f [scan_all $v $p_dev $p_cnt $p_err $p_data $p_fdev]
    puts "=== $tag 有应答的设备号: $f"
}
close_hw_target
exit 0

# ---- 以下是旧的单轮实现, 保留不用 ----
if {0} {
set found {}
for {set d 0} {$d < 16} {incr d} {
    set_property OUTPUT_VALUE [format %X $d] $p_dev   ;# 探针是 HEX 基数, 必须一位十六进制
    commit_hw_vio $p_dev
    refresh_hw_vio $v
    set c0 [expr 0x[get_property INPUT_VALUE $p_cnt]]
    set e0 [expr 0x[get_property INPUT_VALUE $p_err]]
    after 800
    refresh_hw_vio $v
    set c1 [expr 0x[get_property INPUT_VALUE $p_cnt]]
    set e1 [expr 0x[get_property INPUT_VALUE $p_err]]
    set dc [expr {($c1 - $c0) & 0xFFFF}]
    set de [expr {($e1 - $e0) & 0xFFFF}]
    set dt [get_property INPUT_VALUE $p_data]
    set fd [get_property INPUT_VALUE $p_fdev]
    puts [format "===  dev %2d : 新增回包=%-5d 新增错误=%-5d  data0=%s  回包dev=%s" $d $dc $de $dt $fd]
    if {$dc > 0} { lappend found $d }
}
puts "=== 有应答的设备号: $found ==="
}
