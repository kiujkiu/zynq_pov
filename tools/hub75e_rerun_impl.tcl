###############################################################################
# Just re-impl + bitstream (xdc 改了, BD 不动)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened: [current_project]"

# 强制 reset impl_1 (xdc 改触发 out-of-date)
reset_run impl_1
puts "\[INFO\] launching impl_1 → write_bitstream (8 jobs)"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"

if {[string match "*write_bitstream Complete*" $imp_status]} {
    set xsa_path "../hello_plat/hw/hello_zynq.xsa"
    write_hw_platform -fixed -include_bit -force -file [file normalize $xsa_path]
    puts "\[INFO\] xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
