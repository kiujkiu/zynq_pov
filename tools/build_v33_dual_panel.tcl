###############################################################################
# v33 dual-panel 128×128 build
# - FM6124 verilog 加 hub75e_rgb_out2[5:0] output (panel 2 SDI, MVP mirror panel 1)
# - BD update_module_reference 让 cell elaborate 新 port
# - 新建 external port hub75e_rgb2[5:0] connect 出去
# - xdc 已加 6 行 PACKAGE_PIN (hub75e_rgb2[0..5])
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

# Restore sources lost from xpr (v33 build wiped them)
set src_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v"
set xdc_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
if {[lsearch -exact [get_files -quiet] $src_hub75e] < 0} { add_files -norecurse $src_hub75e; puts "\[INFO\] added hub75e_panel_seq.v" }
if {[lsearch -exact [get_files -quiet] $xdc_hub75e] < 0} { add_files -fileset constrs_1 -norecurse $xdc_hub75e; puts "\[INFO\] added hub75e_pins.xdc" }
update_compile_order -fileset sources_1

# Open BD + update module reference for hub75e instance
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

set cell [get_bd_cells hub75e_panel_seq_0]
puts "\[INFO\] cell: $cell"
update_module_reference $cell
puts "\[INFO\] update_module_reference done"

# Create new external port (if not exist)
if {[llength [get_bd_ports -quiet hub75e_rgb2]] == 0} {
    create_bd_port -dir O -from 5 -to 0 -type data hub75e_rgb2
    puts "\[INFO\] created external port hub75e_rgb2[5:0]"
}
# Connect hub75e_panel_seq_0/hub75e_rgb_out2 → external hub75e_rgb2
set src_pin [get_bd_pins -quiet ${cell}/hub75e_rgb_out2]
if {$src_pin != ""} {
    connect_bd_net $src_pin [get_bd_ports hub75e_rgb2]
    puts "\[INFO\] connected hub75e_rgb_out2 → hub75e_rgb2"
} else {
    puts "\[ERROR\] hub75e_rgb_out2 pin not found on $cell — update_module_reference may have failed"
}

validate_bd_design
save_bd_design

# Re-wrap top
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
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
