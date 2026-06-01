###############################################################################
# A: BCM 8-bit PL IP build (PL IP 改了 BCM + 24-bit color, BD 不动)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

# 确认 BD 现在 PS7 FCLK1 = 75 MHz, hub75e DCLK_DIV 默认 4
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]
set fclk1 [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]
puts "\[INFO\] PS7 FCLK1 = $fclk1 MHz (BCM PL IP 跑 DCLK_DIV=4 = ${fclk1}/4 MHz DCLK)"

# 重 wrapper (PL IP 改了寄存器布局 + ports)
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 重 launch (xdc + BD 不变, 只 PL IP source 改了)
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
