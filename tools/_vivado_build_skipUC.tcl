open_project D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

# Use open_bd_design path (the one that worked in validate test)
open_bd_design [get_files hello_zynq.bd]
validate_bd_design
save_bd_design
generate_target all [get_files hello_zynq.bd]
catch {make_wrapper -files [get_files hello_zynq.bd] -top -force}
close_bd_design hello_zynq

puts "TOP: [get_property TOP [get_filesets sources_1]]"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "impl_1 STATUS: $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "xsa exported"
}
close_project
