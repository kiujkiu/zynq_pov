###############################################################################
# 只重 impl + bitstream, 不动 BD (xci 已手动改)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

# 重生成 wrapper 拿新 IP port width
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"

if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] xsa exported"
}
