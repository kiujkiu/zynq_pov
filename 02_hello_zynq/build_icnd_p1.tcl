# build panel1 版: 换 P1 引脚 XDC, 其余沿用 v11 已持久化的 Singular+SmartConnect inline
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
# 1. 加 p1 XDC (若没在工程)
set p1 [get_files -quiet icnd2047_p1.xdc]
if {$p1 eq ""} { add_files -fileset constrs_1 02_hello_zynq.srcs/constrs_1/new/icnd2047_p1.xdc; set p1 [get_files icnd2047_p1.xdc] }
# 2. enable p1, disable 其余所有 panel XDC
foreach x {icnd2047_p3.xdc hub75e_pins.xdc led_pins.xdc} {
    set f [get_files -quiet $x]; if {$f ne ""} { set_property is_enabled false $f }
}
set_property is_enabled true $p1
puts "\[p1\] enabled XDC:"
foreach f [get_files -filter {FILE_TYPE==XDC}] { puts "   [get_property is_enabled $f] [file tail $f]" }
# 3. IP 已升级; BD 已 Singular+inline (持久化). 双保险
set up [get_ips -quiet -filter {IS_LOCKED == 1 || UPGRADE_VERSIONS != ""}]
if {[llength $up]} { upgrade_ip $up }
set bdf [get_files hello_zynq.bd]
set_property synth_checkpoint_mode Singular $bdf
foreach n {axi_smc axi_smc_hp axi_smc_pov_hp sc_pov_axilite} {
  set xx [get_files -quiet "*${n}_0.xci"]; if {$xx ne ""} { catch { set_property generate_synth_checkpoint false $xx } }
}
generate_target all $bdf
catch { create_ip_run [get_files hello_zynq.bd] }
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[p1-RESULT-STATUS\] $st"
puts "\[p1-RESULT-BIT\] [glob -nocomplain 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit]"
# 验脚: dclk 应落 W16
open_run impl_1 -quiet
puts "\[p1-CHK\] dclk@[get_property PACKAGE_PIN [get_ports hub75e_dclk]] b2(rgb5)@[get_property PACKAGE_PIN [get_ports {hub75e_rgb[5]}]]"
exit 0
