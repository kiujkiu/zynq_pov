# v8: angle_tracker 集成 (模块内部改, 不动端口) + sensor_pulse 转 external port
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
set trk "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/angle_tracker.v"
if {[lsearch -exact [get_files -quiet] $trk] < 0} { add_files -norecurse $trk; puts "\[INFO\] angle_tracker.v added" }
update_compile_order -fileset sources_1

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]
# xlconstant 0 → external port
set xc [get_bd_cells -quiet xlconst_sensor0]
if {$xc ne ""} {
    delete_bd_objs [get_bd_nets -quiet -of_objects [get_bd_pins xlconst_sensor0/dout]]
    delete_bd_objs $xc
    puts "\[INFO\] xlconst_sensor0 removed"
}
if {[get_bd_ports -quiet sensor_pulse] eq ""} {
    create_bd_port -dir I sensor_pulse
    connect_bd_net [get_bd_ports sensor_pulse] [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
    puts "\[INFO\] sensor_pulse external port created"
}
validate_bd_design
save_bd_design
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v8 xsa exported"
}
