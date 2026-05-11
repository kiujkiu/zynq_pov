open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

set ss [get_property STATUS [get_runs synth_1]]
puts "synth_1: $ss"
set is [get_property STATUS [get_runs impl_1]]
puts "impl_1: $is"

catch { reset_run impl_1 }
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set is [get_property STATUS [get_runs impl_1]]
puts "impl_1 final: $is"

if {[string match "*Complete*" $is]} {
    open_run impl_1
    write_hw_platform -fixed -include_bit -force \
        D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
    puts "XSA OK"
}
close_project
exit 0
