# synth_check.tcl -- 综合 + 布局 + 时序自检 (不出 bit, 只验设计能不能过)
#
# 跑法 (WSL):
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && \
#     call C:\Xilinx\Vivado\2024.2\settings64.bat && \
#     vivado -mode batch -source tools\synth_check.tcl"
#
# 产出在 build/ 下: synth.rpt (利用率) / timing.rpt / drc.rpt

set root [file normalize [file dirname [info script]]/..]
set build $root/build
file mkdir $build
cd $build

# .mem 用相对路径读, 综合时的工作目录就是这里
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }

read_verilog [list \
    $root/rtl/icnd2260_tx.v \
    $root/rtl/icnd2260_ack_rx.v \
    $root/rtl/icnd2260_seq.v \
    $root/rtl/icnd2260_lxb_top.v ]
read_xdc $root/xdc/lxb_icnd2260_pins.xdc

synth_design -top icnd2260_lxb_top -part xc7z020clg484-1
report_utilization -file $build/synth.rpt
write_checkpoint -force $build/post_synth.dcp

opt_design
place_design
route_design

report_timing_summary -file $build/timing.rpt
report_drc            -file $build/drc.rpt
report_utilization    -file $build/impl_util.rpt

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== SYNTH_CHECK  WNS=$wns  WHS=$whs ==="
if {$wns < 0 || $whs < 0} {
    puts "=== SYNTH_CHECK: TIMING FAIL ==="
} else {
    puts "=== SYNTH_CHECK: TIMING OK ==="
}
