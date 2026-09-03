# build_ppbuf.tcl -- 「直供 + 乒乓 + 每片不同」第一步验证 bit (带 VIO)
#
# 跑法 (WSL):
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && call C:\Xilinx\Vivado\2024.2\settings64.bat && vivado -mode batch -source ppbuf\tools\build_ppbuf.tcl -tclargs 6"
# 产物: ppbuf/build_pp_div6/icnd2260_ppbuf_div6.bit (+ .ltx)
#
# -tclargs <CLK_DIV> [keywords]   6=166.7MHz (默认)  7=142.9  12=83.3
#   synthonly  只综合不布线 (快速看资源)
#   refr64     整表刷新每 64 帧 (默认关: 刷新帧 22,486 拍装不进 18,425 拍的片槽)
# ASCII-only: Vivado on Windows reads .tcl as GBK.
set CLK_DIV 6
set VCO_X8 160
set WR_DIV 8
set EXTRA [list]
set SYNTHONLY 0
set sfx2 ""
if {[llength $argv] > 0} { set CLK_DIV [lindex $argv 0] }
foreach kw $argv {
    switch -- $kw {
        synthonly { set SYNTHONLY 1 }
        refr64    { lappend EXTRA -generic REG_REFRESH_FR=64 ; append sfx2 "_refr64" }
        f143      { set CLK_DIV 7 ; set VCO_X8 160 }
    }
}
set CLK_PHASE_X8 720
set MARGIN [expr {$CLK_DIV >= 12 ? 1.0 : 0.3}]
set BITCLK_NS [expr {double($CLK_DIV)*160.0/double($VCO_X8)}]
set CLK_PHASE_DEG [expr {$CLK_PHASE_X8/8.0}]
set PH_NS [expr {$BITCLK_NS * $CLK_PHASE_DEG / 360.0}]
set TSU   [expr {$PH_NS - $MARGIN}]
set THD   [expr {$BITCLK_NS/2.0 - $PH_NS - $MARGIN}]
set TICK  [expr {int(round(1000.0/$BITCLK_NS * 1e6 / 9045.0))}]   ;# 拍/片 @9,045 fps
puts "=== ppbuf build: CLK_DIV=$CLK_DIV -> bitclk [format %.2f [expr {1000.0/$BITCLK_NS}]] MHz, wr clk [format %.1f [expr {50.0*$VCO_X8/8.0/$WR_DIV}]] MHz, TICK_INIT=$TICK, TSU=$TSU THD=$THD ==="

set here  [file normalize [file dirname [info script]]]      ;# .../icnd2260/ppbuf/tools
set pp    [file normalize $here/..]                          ;# .../icnd2260/ppbuf
set root  [file normalize $pp/..]                            ;# .../icnd2260
set build $pp/build_pp_div$CLK_DIV$sfx2
file mkdir $build
cd $build
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }
set_part xc7z020clg484-1
file mkdir $build/ip

# ---- VIO: 探针宽度与 icnd2260_lxb_ppbuf_top.v 里 vio_pp 的接法逐个对上 ----
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_pp -dir $build/ip
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN      {8} \
    CONFIG.C_PROBE_IN0_WIDTH  {32} \
    CONFIG.C_PROBE_IN1_WIDTH  {16} \
    CONFIG.C_PROBE_IN2_WIDTH  {32} \
    CONFIG.C_PROBE_IN3_WIDTH  {32} \
    CONFIG.C_PROBE_IN4_WIDTH  {32} \
    CONFIG.C_PROBE_IN5_WIDTH  {32} \
    CONFIG.C_PROBE_IN6_WIDTH  {32} \
    CONFIG.C_PROBE_IN7_WIDTH  {32} \
    CONFIG.C_NUM_PROBE_OUT    {13} \
    CONFIG.C_PROBE_OUT0_WIDTH  {8} \
    CONFIG.C_PROBE_OUT1_WIDTH {16} \
    CONFIG.C_PROBE_OUT2_WIDTH  {1} \
    CONFIG.C_PROBE_OUT3_WIDTH  {1} \
    CONFIG.C_PROBE_OUT4_WIDTH  {4} \
    CONFIG.C_PROBE_OUT5_WIDTH  {4} \
    CONFIG.C_PROBE_OUT5_INIT_VAL {0x1} \
    CONFIG.C_PROBE_OUT6_WIDTH {16} \
    CONFIG.C_PROBE_OUT6_INIT_VAL {0x0FFF} \
    CONFIG.C_PROBE_OUT7_WIDTH  {2} \
    CONFIG.C_PROBE_OUT8_WIDTH {24} \
    CONFIG.C_PROBE_OUT8_INIT_VAL [format 0x%06X $TICK] \
    CONFIG.C_PROBE_OUT9_WIDTH {16} \
    CONFIG.C_PROBE_OUT10_WIDTH {1} \
    CONFIG.C_PROBE_OUT11_WIDTH {1} \
    CONFIG.C_PROBE_OUT12_WIDTH {16} \
    CONFIG.C_PROBE_OUT12_INIT_VAL {0x0DAC} \
] [get_ips vio_pp]
generate_target {synthesis instantiation_template} [get_ips vio_pp]
synth_ip [get_ips vio_pp]

read_verilog [list $root/rtl/icnd2260_lvds_tx.v $root/rtl/icnd2260_seq.v \
                   $pp/rtl/angle_tracker.v $pp/rtl/slice_ppbuf.v $pp/rtl/pat_writer.v \
                   $pp/rtl/slice_feed.v $pp/rtl/icnd2260_lxb_ppbuf_top.v]
read_xdc $root/xdc/lxb_icnd2260_lvds_pins.xdc
read_xdc $pp/tools/ppbuf_cdc.xdc
synth_design -top icnd2260_lxb_ppbuf_top -part xc7z020clg484-1 \
    -generic DEBUG=1 -generic CLK_DIV=$CLK_DIV -generic VCO_MULT_X8=$VCO_X8 \
    -generic WR_DIV=$WR_DIV -generic CLK_PHASE_X8=$CLK_PHASE_X8 -generic TICK_INIT=$TICK {*}$EXTRA
set name "icnd2260_ppbuf_div$CLK_DIV$sfx2"
if {$SYNTHONLY} {
    report_utilization -file $build/$name.synth_util.rpt
    puts "=== SYNTH ONLY done -> $build/$name.synth_util.rpt ==="
    return
}
opt_design
place_design
route_design
report_utilization    -file $build/$name.util.rpt
report_timing_summary -file $build/$name.timing.rpt
report_drc            -file $build/$name.drc.rpt
write_bitstream -force $build/$name.bit
write_debug_probes -force $build/$name.ltx
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== BUILD ppbuf  WNS=$wns  WHS=$whs  -> $build/$name.bit (+ .ltx) ==="
if {$wns < 0 || $whs < 0} { puts "=== TIMING NOTE: WNS/WHS < 0 (lvds_top baseline is -0.470 from the MARGIN knob) ===" }
