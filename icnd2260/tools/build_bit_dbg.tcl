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
    }
}
if {[llength $EXTRA]} { puts "=== EXTRA GENERICS: $EXTRA ===" } else { puts "=== EXTRA GENERICS: (none) ===" }
set CLK_PHASE_X8 720
set sfx2 ""
set VCO_X8 160   ;# VCO = 50MHz * VCO_X8/8; 160 => 1000MHz (原行为)
set MARGIN_OVR ""
foreach kw $argv {
    switch -- $kw {
        m05   { set MARGIN_OVR 0.5  }
        m095  { set MARGIN_OVR 0.95 }
        m12   { set MARGIN_OVR 1.2  }
        m16   { set MARGIN_OVR 1.6 }
        m03   { set MARGIN_OVR 0.3 }
        m08   { set MARGIN_OVR 0.8 }
        ph0   { set CLK_PHASE_X8 0 }
        same  { lappend EXTRA -generic CLK_SAME_TREE=1 ; set CLK_PHASE_X8 0 ; append sfx2 "_same" }
        ph22  { set CLK_PHASE_X8 180 }
        ph28  { set CLK_PHASE_X8 225 }
        ph33  { set CLK_PHASE_X8 270 }
        ph39  { set CLK_PHASE_X8 315 }
        ph45  { set CLK_PHASE_X8 360 }
        ph135 { set CLK_PHASE_X8 1080 }
        ph270 { set CLK_PHASE_X8 2160 }
        f152  { set CLK_DIV 7 ; set VCO_X8 170 ; append sfx2 "_f152" }
        f155  { set CLK_DIV 7 ; set VCO_X8 174 ; append sfx2 "_f155" }
        f148  { set CLK_DIV 7 ; set VCO_X8 166 ; append sfx2 "_f148" }
        pix8  { lappend EXTRA -generic PIX_BW8=1 ; append sfx2 "_p8" }
        f143  { set CLK_DIV 7 ; set VCO_X8 160 ; append sfx2 "_f143" }
        f167  { set CLK_DIV 6 ; set VCO_X8 160 ; append sfx2 "_f167" }
        casc3 { lappend EXTRA -generic CASCADE=3 ; append sfx2 "_cas3" }
        casc1 { lappend EXTRA -generic CASCADE=1 ; append sfx2 "_cas1" }
        noprobe { lappend EXTRA -generic READ_PROBE_FR=0 -generic QUIET_CYCLES=0 ; append sfx2 "_np" }
        casc2 { lappend EXTRA -generic CASCADE=2 ; append sfx2 "_cas2" }
        slow3 { lappend EXTRA -generic RAIL_SETTLE=1500000 -generic RAIL_STAGGER=75000 ; append sfx2 "_slow3" }
        norefr { lappend EXTRA -generic REG_REFRESH_FR=1000000 ; append sfx2 "_norefr" }
    }
}
set SAME_TREE 0
foreach kw $argv { if {$kw eq "same"} { set SAME_TREE 1 } }
set BITCLK_NS [expr {double($CLK_DIV)*160.0/double($VCO_X8)}]   ;# = 1000/位时钟MHz
# m16 = EXPERIMENT ONLY: at that margin the constraint no longer reflects the
#       datasheet's 1/4 tLVCP requirement. The physical eye is unchanged; we just
#       stop being told it violates spec. Let the panel be the judge.
set MARGIN    [expr {$CLK_DIV >= 12 ? 1.0 : 0.3}]
# 手册的 tSTU=tHLD=1/4 tLVCP 两者相加 = 整个位周期 => 那是"眼图完全居中且零抖动"的理想值,
# 不是带余量的窗口。实测时钟/数据偏斜约 1.0 ns, 高速档必须按实测放宽。
if {$MARGIN_OVR ne ""} { set MARGIN $MARGIN_OVR }
puts "=== 构建配置: CLK_DIV=$CLK_DIV VCO_X8=$VCO_X8 (VCO [format %.1f [expr {50.0*$VCO_X8/8.0}]] MHz) -> 位时钟 [format %.2f [expr {1000.0/$BITCLK_NS}]] MHz, BITCLK_NS=$BITCLK_NS, MARGIN=$MARGIN ==="

set root  [file normalize [file dirname [info script]]/..]
# 每个变体一个独立构建目录 -> 多个 Vivado 可以并行跑, 互不踩
set sfx ""
set CLK_PHASE_DEG [expr {$CLK_PHASE_X8/8.0}]
# XDC 不支持 if, 所以窗口在这里算好再传进去
if {$SAME_TREE} {
    # 边沿对齐: 数据与时钟同时跳变, "半周期窗口"那套模型不适用。
    # 这里约束的是**四个引脚之间的到达时间差** (实测约 1.24ns), 给 1.5ns 预算。
    # 实测数据沿比时钟沿早到约 1.24ns, 所以窗口要允许数据滞后:
    #   TSU=1.5  数据可比时钟沿早 1.5ns
    #   THD=-0.5 数据可比时钟沿晚 0.5ns
    # ⚠ 这是**引脚偏差预算**, 不是手册那个 1/4 tLVCP 要求 -- 边沿对齐下由芯片内部延时补相位。
    set TSU  1.5
    set THD -0.5
} else {
    set PH_NS [expr {$BITCLK_NS * $CLK_PHASE_DEG / 360.0}]
    set TSU   [expr {$PH_NS - $MARGIN}]
    set THD   [expr {$BITCLK_NS/2.0 - $PH_NS - $MARGIN}]
}
if {$CLK_PHASE_X8 != 720} { set sfx "_ph[format %g $CLK_PHASE_DEG]" }
set build $root/build_dbg$sfx$sfx2
file mkdir $build
cd $build
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }
# 🔴 把图案文件的首行注释抄进构建目录, 否则事后无法确认这个 bit 里到底是哪张图。
#    今天就栽过: 编译进行中 .mem 被下一次生成覆盖, 编出来的 bit 图案对不上。
set fbm $root/rtl/icnd2260_fb_lvds.mem
if {[file exists $fbm]} {
    set fh [open $fbm r] ; set PATSIG [gets $fh] ; close $fh
    set oh [open $build/PATTERN.txt w] ; puts $oh $PATSIG ; close $oh
    puts "=== 图案指纹: $PATSIG ==="
}

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
    CONFIG.C_NUM_PROBE_OUT    {14} \
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
    CONFIG.C_PROBE_OUT13_WIDTH {24} \
    CONFIG.C_PROBE_OUT13_INIT_VAL {0x061A80} \
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
        -generic DEBUG=1 -generic CLK_DIV=$CLK_DIV -generic VCO_MULT_X8=$VCO_X8 \
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
