# 强制重生成 BD 结构 HDL (含 sensor_pulse external port) + 重 build
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
open_bd_design [get_files hello_zynq.bd]
# 确认 sensor_pulse 连接还在 (BD 层正确)
puts "\[INFO\] sensor net: [get_bd_nets -quiet -of_objects [get_bd_pins hub75e_panel_seq_0/sensor_pulse]]"
validate_bd_design
save_bd_design
# 强制重生成全部 target (reset 清缓存)
reset_target all [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] bd-regen-sensor xsa exported"
}
