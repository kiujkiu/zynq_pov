# Quick rebuild: just resynth + impl, do not regen BD
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

# Re-add hub75e_panel_seq.v if missing
set hub_file [file normalize 02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v]
if {[lsearch -exact [get_files] $hub_file] < 0} {
    puts "[INFO] adding hub75e_panel_seq.v"
    add_files -norecurse $hub_file
}

# refresh BD
open_bd_design [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd]
catch { make_wrapper -files [get_files hello_zynq.bd] -top -force }

reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "[INFO] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "[INFO] xsa exported"
}
