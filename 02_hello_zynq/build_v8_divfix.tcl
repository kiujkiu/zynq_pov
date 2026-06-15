# v8 divfix: angle_tracker 除法器 dividend bug 修复 (rev_cnt→rev_period) + slice_max/locked_ever 0x30 调试锁存
# 纯内部逻辑改动, 无端口变化, BD 不动. 只重综合/impl/导出.
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] divfix xsa exported"
} else {
    puts "\[ERROR\] impl failed: $st"
}
exit 0
