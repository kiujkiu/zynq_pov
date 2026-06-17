# v11: 顺GUI纹理 — Singular BD OOC run(生成 hello_zynq.dcp) + SmartConnect inline(解嵌套黑盒) + 级联 impl
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
set bdf [get_files hello_zynq.bd]
# IP 已升级(之前持久化); 双保险再 upgrade 一次
set up [get_ips -quiet -filter {IS_LOCKED == 1 || UPGRADE_VERSIONS != ""}]
if {[llength $up]} { puts "\[v11\] upgrading: $up"; upgrade_ip $up }
# Singular = BD 顶层 OOC 综合成 hello_zynq.dcp (synth_1 顶层读它, GUI 就是这流程)
set_property synth_checkpoint_mode Singular $bdf
# SmartConnect 不出独立 OOC dcp → 在 BD OOC 综合里内联 (解 INBB-3 黑盒)
foreach n {axi_smc axi_smc_hp axi_smc_pov_hp sc_pov_axilite} {
  set x [get_files -quiet "*${n}_0.xci"]
  if {$x ne ""} { catch { set_property generate_synth_checkpoint false $x } }
}
generate_target all $bdf
# 创建 BD OOC run (fresh worktree 缺, 这是 GUI 'Generate Output Products' 干的事)
catch { create_ip_run [get_files hello_zynq.bd] } cmsg
puts "\[v11\] create_ip_run: $cmsg"
puts "\[v11\] runs: [get_runs]"
reset_run synth_1
reset_run impl_1
# 级联: 自动先跑 hello_zynq_synth_1(BD OOC) → synth_1(顶层) → impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[v11-RESULT-STATUS\] $st"
puts "\[v11-RESULT-BIT\] [glob -nocomplain 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit]"
exit 0
