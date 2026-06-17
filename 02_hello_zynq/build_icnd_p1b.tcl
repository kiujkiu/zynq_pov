# build P1 + 强制 panel IP inline (防 module_ref OOC dcp 缓存 → RTL改动不生效)
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
# XDC: P1
set p1 [get_files -quiet icnd2047_p1.xdc]
foreach x {icnd2047_p3.xdc hub75e_pins.xdc led_pins.xdc} {
    set f [get_files -quiet $x]; if {$f ne ""} { set_property is_enabled false $f }
}
if {$p1 ne ""} { set_property is_enabled true $p1 }
# upgrade
set up [get_ips -quiet -filter {IS_LOCKED == 1 || UPGRADE_VERSIONS != ""}]
if {[llength $up]} { upgrade_ip $up }
set bdf [get_files hello_zynq.bd]
set_property synth_checkpoint_mode Singular $bdf
# SmartConnect + PANEL IP 全部 inline (panel IP 关键: 避免 OOC dcp 缓存旧 RTL)
foreach n {axi_smc axi_smc_hp axi_smc_pov_hp sc_pov_axilite hub75e_panel_seq} {
  set xx [get_files -quiet "*${n}_0*.xci"]
  if {$xx ne ""} { catch { set_property generate_synth_checkpoint false $xx; puts "inline: $xx" } }
}
# 删 panel IP 的 OOC synth run + .gen 产物, 强制从当前 RTL 重生成
foreach r [get_runs -quiet *hub75e_panel_seq*] { catch { delete_runs $r; puts "del run $r" } }
reset_target -quiet all $bdf
generate_target all $bdf
update_compile_order -fileset sources_1
catch { create_ip_run [get_files hello_zynq.bd] }
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
puts "\[p1b-STATUS\] [get_property STATUS [get_runs impl_1]]"
puts "\[p1b-BIT\] [glob -nocomplain 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit]"
exit 0
