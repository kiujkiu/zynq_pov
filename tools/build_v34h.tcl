# v34h build: panel 1 R2/G2 swap (Y20↔AB21) + DRIVE 4 SLEW SLOW
# 目的: 修 v34g 的 "R 开 B 整掉" 串扰 bug
# 改动: 02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc (已 stage 在 working tree)
#       BD / IP 无改, 直接 reset_run + rebuild

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

puts "\[INFO\] BD validate + regen wrapper"
open_bd_design [get_files hello_zynq.bd]
report_ip_status
catch { upgrade_bd_cells [get_bd_cells] }
validate_bd_design -force
save_bd_design
generate_target all [get_files hello_zynq.bd]

catch { make_wrapper -files [get_files hello_zynq.bd] -top -force }
catch { add_files -norecurse [glob -nocomplain [file normalize [get_property directory [current_project]]]/02_hello_zynq.gen/sources_1/bd/hello_zynq/hdl/hello_zynq_wrapper.v] }

reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v34h xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
