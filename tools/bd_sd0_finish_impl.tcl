# Finish impl + bit + XSA after synth succeeded
set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
open_project "$proj_dir/02_hello_zynq.xpr"
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

puts "=== launch impl_1 to write_bitstream ==="
catch { reset_run impl_1 }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "=== export XSA ==="
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"

puts "=== DONE ==="
close_project
exit 0
