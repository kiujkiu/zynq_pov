open_project 02_hello_zynq.xpr
set f [get_files -quiet *angle_tracker.v]
if {$f ne ""} { remove_files $f; puts "removed angle_tracker.v from project" }
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v8-inline xsa exported"
}
