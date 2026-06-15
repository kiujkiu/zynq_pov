# 核选项: 全清 .gen + synth/impl runs, 从 .bd 完全从头 regen → synth → impl
# 目标: 破掉所有 BD/module_ref 综合缓存, 让 sensor_pulse 真正进 netlist
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

# 1. 强制 reset BD 全部 target (删 .gen 产物)
open_bd_design [get_files hello_zynq.bd]
puts "\[INFO\] sensor net (确认连接): [get_bd_nets -quiet -of_objects [get_bd_pins hub75e_panel_seq_0/sensor_pulse]]"
validate_bd_design
save_bd_design
reset_target all [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd]
export_ip_user_files -of_objects [get_files hello_zynq.bd] -no_script -sync -force -quiet
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 2. 强制 reset runs (删 synth/impl 缓存)
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_runs synth_1
# 验证 synth 后 sensor_pulse 在不在
open_run synth_1 -name synth_chk
puts "\[CHECK\] sensor_pulse port: [get_ports -quiet sensor_pulse]"
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] nuclear-regen xsa exported"
}
