# Just write XSA from impl_1 output (impl already done by subprocess)
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set is [get_property STATUS [get_runs impl_1]]
puts "impl_1: $is"
if {[string match "*Complete*" $is] || [string match "*Routed*" $is]} {
    open_run impl_1
    write_hw_platform -fixed -include_bit -force \
        D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
    puts "XSA OK"
} else {
    puts "NOT READY: $is"
}
close_project
exit 0
