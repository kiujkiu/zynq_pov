###############################################################################
# v30 ICND2047 panel driver build
# - hub75e_panel_seq_v2 module 现在是 ICND2047 实现 (icnd2047_panel_seq.v 内)
# - 原 FM6124 实现 module rename 为 hub75e_panel_seq_v2_fm6124 (避免 duplicate)
# - BD 不动 (FCLK1 75M build-time, runtime mwr SLCR 改 50M → DCLK 25M)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

# Add ICND2047 verilog to sources_1 (新文件不在 xpr fileset)
set icnd_src "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v"
if {[lsearch -exact [get_files] $icnd_src] < 0} {
    add_files -norecurse $icnd_src
    puts "\[INFO\] added icnd2047_panel_seq.v to sources_1"
}
update_compile_order -fileset sources_1

# 重新 wrap (BD 端口未变, 安全 force)
open_bd_design [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 重 build
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
