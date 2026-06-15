# workaround: panel_spi_miso (已验证 survive 的 input port) fanout 给 hub75e sensor_pulse
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
open_bd_design [get_files hello_zynq.bd]
# hub75e sensor_pulse 当前接 sensor_pulse_1(dead). 断开
set hp [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
set oldnet [get_bd_nets -quiet -of_objects $hp]
puts "old hub75e sensor net: $oldnet"
# 断开 hub75e 旧 net (dead sensor_pulse_1) + 删旧 sensor_pulse 外部端口
if {$oldnet ne ""} { delete_bd_objs $oldnet }
catch { delete_bd_objs [get_bd_ports -quiet sensor_pulse] }
# 把 hub75e sensor_pulse fanout 到 panel_spi_miso 端口 (该端口已驱动 axi_gpio, net 活的)
connect_bd_net [get_bd_pins hub75e_panel_seq_0/sensor_pulse] [get_bd_ports panel_spi_miso_tri_i]
puts "connected hub75e/sensor_pulse <- panel_spi_miso port (fanout)"
validate_bd_design
save_bd_design
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
    puts "\[INFO\] workaround xsa exported"
}
