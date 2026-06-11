open_project 02_hello_zynq.xpr
set f [get_files -of [get_filesets sources_1] -filter "NAME =~ *hub75e_panel_seq.v"]
puts "file: $f"
puts "FILE_TYPE: [get_property FILE_TYPE $f]"
puts "USED_IN: [get_property USED_IN $f]"
puts "USED_IN_SYNTHESIS: [get_property USED_IN_SYNTHESIS $f]"
puts "USED_IN_IMPLEMENTATION: [get_property USED_IN_IMPLEMENTATION $f]"
puts "IS_AVAILABLE: [get_property IS_AVAILABLE $f]"
puts "IS_ENABLED: [get_property IS_ENABLED $f]"
puts "----"
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1
puts "After update_compile_order:"
puts "top: [get_property TOP [get_filesets sources_1]]"
close_project
