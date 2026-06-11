open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

# Regenerate the module_ref to pick up new verilog
open_bd_design [get_files hello_zynq.bd]
puts "[INFO] update_module_reference"
update_module_reference hello_zynq_hub75e_panel_seq_0_1
validate_bd_design -force
save_bd_design
generate_target all [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force

puts "[INFO] launching impl_1"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "impl_1 STATUS: $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "xsa exported"
}
close_project
