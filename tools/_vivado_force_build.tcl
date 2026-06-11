open_project 02_hello_zynq.xpr
# Force source mgmt off, manually set top
set_property source_mgmt_mode DisplayOnly [current_project]
set_property top hello_zynq_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "TOP = [get_property TOP [get_filesets sources_1]]"
puts "files count: [llength [get_files -of [get_filesets sources_1]]]"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
puts "impl_1 STATUS: [get_property STATUS [get_runs impl_1]]"
if {[string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "xsa exported"
}
close_project
