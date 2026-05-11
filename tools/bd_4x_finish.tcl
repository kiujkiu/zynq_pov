# Continue impl_1 + bitstream + XSA (synth_1 already done from previous run)
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]

# Verify synth_1 done
set ss [get_property STATUS [get_runs synth_1]]
puts "synth_1 status: $ss"

# Launch impl_1 to write_bitstream
catch { reset_run impl_1 }
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set is [get_property STATUS [get_runs impl_1]]
puts "impl_1 status: $is"

if {$is eq "write_bitstream Complete!"} {
    puts "=== Export XSA ==="
    open_run impl_1
    write_hw_platform -fixed -include_bit -force \
        D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
    puts "XSA exported OK"
} else {
    puts "impl_1 FAILED"
}
close_project
exit 0
