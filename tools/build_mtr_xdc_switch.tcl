# 切换到转接板 XDC: disable 直连版, enable mtr_v01, impl-only 重跑
open_project 02_hello_zynq.xpr
set old "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
set new "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins_mtr_v01.xdc"
if {[lsearch -exact [get_files -quiet] $new] < 0} { add_files -fileset constrs_1 -norecurse $new; puts "\[INFO\] mtr xdc added" }
set_property is_enabled false [get_files $old]
set_property is_enabled true  [get_files $new]
puts "\[INFO\] XDC switched: direct OFF, mtr_v01 ON"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] mtr-xdc xsa exported"
}
