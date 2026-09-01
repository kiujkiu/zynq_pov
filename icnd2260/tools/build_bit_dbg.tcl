# build_bit_dbg.tcl -- 带 VIO 调试核的 mini-LVDS bitstream
#
# 跑法:
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && \
#     call C:\Xilinx\Vivado\2024.2\settings64.bat && \
#     vivado -mode batch -source tools\build_bit_dbg.tcl"
#
# 产物: build_dbg/icnd2260_lvds_dbg.bit  (+ .ltx 探针文件, Hardware Manager 要用)
#
# 用法 (Vivado Hardware Manager):
#   1. open_hw_manager -> connect -> 选 xc7z020 -> 指定 .bit 和 .ltx -> program
#   2. 打开 hw_vio_1, 加 probe
#   3. 读: frame_cnt / status / ack_* ; 写: reg_addr+reg_data, 然后把 we_tog 翻一下
#
# ⚠ 纯 PL 设计走 JTAG 配置, 鹿小班 boot mode 拨到 JTAG。

# -tclargs <CLK_DIV>   24=41.7MHz(默认)  48=20.8MHz  12=83.3MHz  6=166.7MHz
set CLK_DIV 24
set VARIANT lvds
if {[llength $argv] > 0} { set CLK_DIV [lindex $argv 0] }
if {[llength $argv] > 1} { set VARIANT [lindex $argv 1] }   ;# lvds | ttl (ttl 固定 25MHz, CLK_DIV 忽略)
# XDC 里的时序窗口跟着位时钟走; 位时钟周期(ns) = CLK_DIV
# -tclargs <CLK_DIV> [variant] [extra generics]  e.g. "-generic VID_CRC=0"
set EXTRA [list]
# NOTE: cmd.exe treats BOTH spaces and '=' as -tclargs delimiters, so we cannot
#       pass "-generic VID_CRC=0" directly. Pass a keyword instead and build it here.
#       Keep this block ASCII-only: Vivado on Windows reads .tcl as GBK.
foreach kw $argv {
    switch -- $kw {
        novidcrc { lappend EXTRA -generic VID_CRC=0 }
        lines48  { lappend EXTRA -generic LINES=48 ; append sfx2 "_L48" }
        gap8k    { lappend EXTRA -generic FRAME_GAP=8192   ; append sfx2 "_g8k"   }
        gap32k   { lappend EXTRA -generic FRAME_GAP=32768  ; append sfx2 "_g32k"  }
        gap100k  { lappend EXTRA -generic FRAME_GAP=100000 ; append sfx2 "_g100k" }
        gap400k  { lappend EXTRA -generic FRAME_GAP=400000 ; append sfx2 "_g400k" }
        casc3    { lappend EXTRA -generic CASCADE=3 }
        casc1    { lappend EXTRA -generic CASCADE=1 }
    }
}
if {[llength $EXTRA]} { puts "=== EXTRA GENERICS: $EXTRA ===" } else { puts "=== EXTRA GENERICS: (none) ===" }
set CLK_PHASE_X8 720
set sfx2 ""
foreach kw $argv {
    switch -- $kw {
        ph0   { set CLK_PHASE_X8 0 }
        ph22  { set CLK_PHASE_X8 180 }
        ph28  { set CLK_PHASE_X8 225 }
        ph45  { set CLK_PHASE_X8 360 }
        ph135 { set CLK_PHASE_X8 1080 }
        ph270 { set CLK_PHASE_X8 2160 }
    }
}
set BITCLK_NS [expr {double($CLK_DIV)}]
set MARGIN    [expr {$CLK_DIV >= 12 ? 1.0 : 0.3}]
puts "=== 构建配置: CLK_DIV=$CLK_DIV -> 位时钟 [format %.2f [expr {1000.0/$CLK_DIV}]] MHz, BITCLK_NS=$BITCLK_NS, MARGIN=$MARGIN ==="

set root  [file normalize [file dirname [info script]]/..]
# 每个变体一个独立构建目录 -> 多个 Vivado 可以并行跑, 互不踩
set sfx ""
set CLK_PHASE_DEG [expr {$CLK_PHASE_X8/8.0}]
if {$CLK_PHASE_X8 != 720} { set sfx "_ph[format %g $CLK_PHASE_DEG]" }
set build $root/build_dbg$sfx$sfx2
file mkdir $build
cd $build
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }

set_part xc7z020clg484-1
file mkdir $build/ip          ;# create_ip 不会自己建目录, 少这句直接报 Common 17-69

# ---- 生成 VIO IP ----------------------------------------------------------
# 探针宽度必须和 icnd2260_lxb_lvds_top.v 里 vio_dbg 的接法逐个对上, 改一边就要改另一边。
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_dbg -dir $build/ip
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN      {8} \
    CONFIG.C_PROBE_IN0_WIDTH  {32} \
    CONFIG.C_PROBE_IN1_WIDTH  {16} \
    CONFIG.C_PROBE_IN2_WIDTH  {16} \
    CONFIG.C_PROBE_IN3_WIDTH  {24} \
    CONFIG.C_PROBE_IN4_WIDTH  {16} \
    CONFIG.C_PROBE_IN5_WIDTH  {16} \
    CONFIG.C_PROBE_IN6_WIDTH   {9} \
    CONFIG.C_PROBE_IN7_WIDTH  {32} \
    CONFIG.C_NUM_PROBE_OUT    {13} \
    CONFIG.C_PROBE_OUT0_WIDTH  {8} \
    CONFIG.C_PROBE_OUT1_WIDTH {16} \
    CONFIG.C_PROBE_OUT2_WIDTH  {1} \
    CONFIG.C_PROBE_OUT3_WIDTH  {8} \
    CONFIG.C_PROBE_OUT4_WIDTH  {1} \
    CONFIG.C_PROBE_OUT5_WIDTH  {1} \
    CONFIG.C_PROBE_OUT6_WIDTH  {4} \
    CONFIG.C_PROBE_OUT7_WIDTH  {1} \
    CONFIG.C_PROBE_OUT8_WIDTH  {1} \
    CONFIG.C_PROBE_OUT9_WIDTH  {4} \
    CONFIG.C_PROBE_OUT10_WIDTH {4} \
    CONFIG.C_PROBE_OUT11_WIDTH {3} \
    CONFIG.C_PROBE_OUT12_WIDTH {16} \
    CONFIG.C_PROBE_OUT12_INIT_VAL {0x0FFF} \
    CONFIG.C_PROBE_OUT10_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x00} \
    CONFIG.C_PROBE_OUT3_INIT_VAL {0x00} \
] [get_ips vio_dbg]
generate_target {synthesis instantiation_template} [get_ips vio_dbg]
synth_ip [get_ips vio_dbg]

# ---- 主设计 ---------------------------------------------------------------
if {$VARIANT eq "ttl"} {
    read_verilog [list $root/rtl/icnd2260_tx.v $root/rtl/icnd2260_ack_rx.v \
                       $root/rtl/icnd2260_seq.v $root/rtl/icnd2260_lxb_top.v]
    read_xdc $root/xdc/lxb_icnd2260_pins.xdc
    synth_design -top icnd2260_lxb_top -part xc7z020clg484-1 -generic DEBUG=1
} else {
    read_verilog [list $root/rtl/icnd2260_lvds_tx.v $root/rtl/icnd2260_ack_rx.v \
                       $root/rtl/icnd2260_seq.v $root/rtl/icnd2260_lxb_lvds_top.v]
    read_xdc $root/xdc/lxb_icnd2260_lvds_pins.xdc
    synth_design -top icnd2260_lxb_lvds_top -part xc7z020clg484-1 \
        -generic DEBUG=1 -generic CLK_DIV=$CLK_DIV \
        -generic CLK_PHASE_X8=$CLK_PHASE_X8 {*}$EXTRA
}
opt_design
place_design
route_design

set name [expr {$VARIANT eq "ttl" ? "icnd2260_ttl_dbg" : "icnd2260_lvds_dbg_div$CLK_DIV"}]
append name $sfx$sfx2
puts "=== PHASE: CLK_PHASE_DEG=$CLK_PHASE_DEG  TSU=$TSU  THD=$THD  -> $name ==="
report_utilization    -file $build/$name.util.rpt
report_timing_summary -file $build/$name.timing.rpt
report_drc            -file $build/$name.drc.rpt
write_bitstream -force $build/$name.bit
write_debug_probes -force $build/$name.ltx

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== BUILD dbg  WNS=$wns  WHS=$whs  -> $build/$name.bit (+ .ltx) ==="
if {$wns < 0 || $whs < 0} { puts "=== TIMING FAIL, 这个 bit 别烧 ===" }
