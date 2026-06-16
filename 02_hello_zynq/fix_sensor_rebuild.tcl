# 重新接 panel_spi_miso → hub75e/sensor_pulse (绕 const0 workaround, 集成时被 checkout 丢了)
# 保留 pov_proj. 重建 bit + 导出 xsa. 这次务必 commit .bd.
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
open_bd_design [get_files hello_zynq.bd]

# 断开 hub75e/sensor_pulse 当前的死 net + 删死外部端口 sensor_pulse
set hp [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
set oldnet [get_bd_nets -quiet -of_objects $hp]
puts "old net: $oldnet"
if {$oldnet ne ""} { delete_bd_objs $oldnet }
catch { delete_bd_objs [get_bd_ports -quiet sensor_pulse] }
# fanout: panel_spi_miso 端口 (已驱动 axi_gpio) 共享给 hub75e/sensor_pulse
connect_bd_net [get_bd_pins hub75e_panel_seq_0/sensor_pulse] [get_bd_ports panel_spi_miso_tri_i]
puts "connected hub75e/sensor_pulse <- panel_spi_miso (fanout)"

set vrc [catch { validate_bd_design } verr]
puts "VALIDATE: [expr {$vrc==0 ? {OK} : {FAIL}}]"
if {$vrc != 0} { puts "VERR: $verr"; close_project; exit 1 }
save_bd_design
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
    puts "\[INFO\] sensor-fix xsa exported"
} else { puts "\[ERROR\] impl failed: $st" }
exit 0
