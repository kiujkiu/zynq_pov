# v34c: 同 v34b 但 wrapper 已 fixed (含 rgb2), 只重 synth + impl, BD 不动
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

set src_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v"
set xdc_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
if {[lsearch -exact [get_files -quiet] $src_hub75e] < 0} { add_files -norecurse $src_hub75e }
if {[lsearch -exact [get_files -quiet] $xdc_hub75e] < 0} { add_files -fileset constrs_1 -norecurse $xdc_hub75e }
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
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
