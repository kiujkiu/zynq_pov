# 重建 bitstream (含新 pov_proj IP). BD 已集成 validated. 生成 BD 产物 + wrapper + impl + bit + xsa.
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
# BD 产物 (新 IP)
generate_target all [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] pov_proj xsa exported"
} else {
    puts "\[ERROR\] impl failed: $st"
}
exit 0
