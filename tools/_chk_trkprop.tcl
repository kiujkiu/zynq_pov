open_project 02_hello_zynq.xpr
set f [get_files -quiet *angle_tracker.v]
puts "file: $f"
puts "used_in_synthesis: [get_property USED_IN_SYNTHESIS $f]"
puts "used_in: [get_property USED_IN $f]"
puts "file_type: [get_property FILE_TYPE $f]"
puts "is_enabled: [get_property IS_ENABLED $f]"
