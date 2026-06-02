###############################################################################
# Force regen IP outputs + synth+impl+bitstream (用于改 BD xci 参数后)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# Force regen all IP output products
puts "\[INFO\] reset + regenerate all IP targets"
reset_target all [get_files hello_zynq.bd]
generate_target -force all [get_files hello_zynq.bd]

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
} else {
    puts "\[ERROR\] impl_1 failed: $imp_status"
}
