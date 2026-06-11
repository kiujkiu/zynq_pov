open_project 02_hello_zynq.xpr
puts "[get_property STATUS [get_runs synth_1]]"
puts "[get_property STATUS [get_runs impl_1]]"
puts "files in sources_1:"
puts [llength [get_files -of [get_filesets sources_1]]]
puts "files matching hub75e:"
puts [get_files -of [get_filesets sources_1] -filter "NAME =~ *hub75e*"]
close_project
