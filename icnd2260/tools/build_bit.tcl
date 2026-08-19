# build_bit.tcl -- 出 bitstream (可直接 JTAG 烧)
#
# 跑法 (WSL):
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && \
#     call C:\Xilinx\Vivado\2024.2\settings64.bat && \
#     vivado -mode batch -source tools\build_bit.tcl -tclargs lvds"
#
#   -tclargs lvds   → mini-LVDS 版 (需先把 BANK 33 改 2.5V)
#   -tclargs ttl    → TTL 版 (3.3V 就能跑, 没做电阻改动时用这个)
#
# 产物: build_bit/icnd2260_<变体>.bit  + 同名 .rpt (时序/DRC/利用率)
#
# ⚠ 纯 PL 设计, 没有 PS7 ⇒ report_drc 会有一条 ZPS7-1 警告, 是正常的。
#   烧之前把鹿小班的 boot mode 拨到 JTAG。

set variant "lvds"
if {[llength $argv] > 0} { set variant [lindex $argv 0] }

set root  [file normalize [file dirname [info script]]/..]
set build $root/build_bit
file mkdir $build
cd $build
foreach m [glob -nocomplain $root/rtl/*.mem] { file copy -force $m $build }

switch -- $variant {
    lvds {
        set top  icnd2260_lxb_lvds_top
        set srcs [list $root/rtl/icnd2260_lvds_tx.v \
                       $root/rtl/icnd2260_ack_rx.v \
                       $root/rtl/icnd2260_seq.v \
                       $root/rtl/icnd2260_lxb_lvds_top.v]
        set xdc  $root/xdc/lxb_icnd2260_lvds_pins.xdc
    }
    ttl {
        set top  icnd2260_lxb_top
        set srcs [list $root/rtl/icnd2260_tx.v \
                       $root/rtl/icnd2260_ack_rx.v \
                       $root/rtl/icnd2260_seq.v \
                       $root/rtl/icnd2260_lxb_top.v]
        set xdc  $root/xdc/lxb_icnd2260_pins.xdc
    }
    default { error "变体只能是 lvds 或 ttl, 收到: $variant" }
}

read_verilog $srcs
read_xdc $xdc
synth_design -top $top -part xc7z020clg484-1
opt_design
place_design
route_design

set name icnd2260_$variant
report_utilization    -file $build/$name.util.rpt
report_timing_summary -file $build/$name.timing.rpt
report_drc            -file $build/$name.drc.rpt
write_bitstream -force $build/$name.bit

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== BUILD $variant  WNS=$wns  WHS=$whs  -> $build/$name.bit ==="
if {$wns < 0 || $whs < 0} { puts "=== ⚠ 时序没收敛, 这个 bit 别烧 ===" }
