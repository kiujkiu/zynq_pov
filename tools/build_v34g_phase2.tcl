# v34g Phase 2 dual BRAM build (panel 2 独立 BRAM, 128x128 拼接)
# - panel_seq_v3 → v4 (port width 16→17)
# - BD addr segment 64K → 128K
# - 删 IP cache 强制 regen

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

# 重新 hierarchy update + report
update_compile_order -fileset sources_1

# BD regen
puts "\[INFO\] BD validate + regen wrapper"
open_bd_design [get_files hello_zynq.bd]
report_ip_status
catch { upgrade_bd_cells [get_bd_cells] }
validate_bd_design -force
save_bd_design
generate_target all [get_files hello_zynq.bd]

# 重新生成 wrapper
catch { make_wrapper -files [get_files hello_zynq.bd] -top -force }
catch { add_files -norecurse [glob -nocomplain [file normalize [get_property directory [current_project]]]/02_hello_zynq.gen/sources_1/bd/hello_zynq/hdl/hello_zynq_wrapper.v] }

# reset synth + impl
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v34g xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
