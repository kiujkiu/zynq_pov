# 强制 module_ref IP 重生成 (拾取 angle_tracker.v 依赖), 修 sensor_pulse 被 trim
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
# 确保 angle_tracker.v 在 sources
set trk "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/angle_tracker.v"
if {[lsearch -exact [get_files -quiet] $trk] < 0} { add_files -norecurse $trk }
update_compile_order -fileset sources_1

open_bd_design [get_files hello_zynq.bd]
# reset + regenerate module_ref IP output products (强制重扫依赖)
reset_target all [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
save_bd_design

reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] sensor-regen xsa exported"
}
