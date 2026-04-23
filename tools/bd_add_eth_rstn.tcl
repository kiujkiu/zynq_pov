# bd_add_eth_rstn.tcl
# 追加: PHY 硬件复位 eth_rstn (H17 pin) 接常量 1
# 参考: vendor 纯 PL UDP 回环工程里就是 assign eth_rstn = 1

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# 加一个 xlconstant (1-bit value=1) 专门给 eth_rstn
if {![llength [get_bd_cells -quiet eth_rstn_const]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 eth_rstn_const
}
set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] \
    [get_bd_cells eth_rstn_const]

# 创建外部端口 eth_rstn
if {![llength [get_bd_ports -quiet eth_rstn]]} {
    create_bd_port -dir O -type undef eth_rstn
}

# 连 const → ext port
set ext [get_bd_ports eth_rstn]
set src [get_bd_pins eth_rstn_const/dout]
if {![llength [get_bd_nets -quiet -of_objects $ext]]} {
    connect_bd_net $src $ext
}

catch {validate_bd_design} e
puts "validate: $e"
save_bd_design
generate_target all [get_files ${bd_name}.bd] -force

# 更新 XDC
set xdc "$proj_dir/02_hello_zynq.srcs/constrs_1/new/eth_pins.xdc"
set fh [open $xdc "a"]
puts $fh ""
puts $fh "## PHY hardware reset (tied high, matching vendor PL UDP loopback ref)"
puts $fh "set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } \[get_ports eth_rstn\];"
close $fh

reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl: [get_property STATUS [get_runs impl_1]]"

open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
exit 0
