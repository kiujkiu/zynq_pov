# synth_check_lvds.tcl -- mini-LVDS 版的综合+布线+时序+DRC 自检
set root [file normalize [file dirname [info script]]/..]
set build $root/build_lvds
file mkdir $build
cd $build
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }

read_verilog [list \
    $root/rtl/icnd2260_lvds_tx.v \
    $root/rtl/icnd2260_seq.v \
    $root/rtl/icnd2260_lxb_lvds_top.v ]
read_xdc $root/xdc/lxb_icnd2260_lvds_pins.xdc

synth_design -top icnd2260_lxb_lvds_top -part xc7z020clg484-1
opt_design
place_design
route_design
report_timing_summary -file $build/timing.rpt
report_drc            -file $build/drc.rpt
report_utilization    -file $build/util.rpt

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== LVDS_CHECK  WNS=$wns  WHS=$whs ==="
