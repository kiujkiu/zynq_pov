set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
open_project "$proj_dir/02_hello_zynq.xpr"
set_property source_mgmt_mode None [current_project]
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
exit 0
