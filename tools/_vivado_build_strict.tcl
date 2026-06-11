open_project 02_hello_zynq.xpr
# Force read all verilog files and check syntax
set v_files [get_files -of [get_filesets sources_1] -filter "FILE_TYPE == Verilog"]
puts "Verilog files: [llength $v_files]"
foreach f $v_files {
    set en [get_property IS_ENABLED $f]
    if {!$en} { puts "DISABLED: $f" }
}

# Manual top + force compile order
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1
puts "TOP: [get_property TOP [get_filesets sources_1]]"

launch_runs synth_1 -jobs 8
wait_on_runs synth_1
puts "synth_1 STATUS: [get_property STATUS [get_runs synth_1]]"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "impl_1 STATUS: $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "xsa exported"
}
close_project
