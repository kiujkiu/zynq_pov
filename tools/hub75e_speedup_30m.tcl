###############################################################################
# Step C: PS7 FCLK1 = 60 MHz + DCLK_DIV=2 → DCLK 30 MHz (FM6124 spec max)
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

# 1. open BD
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# 2. PS7 FCLK1 = 50 MHz (PS7 GUI 拒绝 60/100/120, 50 是 valid PCW 标准值)
#    50 MHz aclk + DCLK_DIV=2 = 25 MHz DCLK, 50% 占空 TWCLK 20 ns 满足 spec
set ps7_curr [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]
puts "\[INFO\] PS7 FCLK_CLK1 当前 = $ps7_curr MHz, 改为 50 MHz"
set_property -dict [list \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {50} \
] [get_bd_cells processing_system7_0]
set ps7_new [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]
puts "\[INFO\] PS7 FCLK_CLK1 实际设到 = $ps7_new MHz"

# 3. hub75e_panel_seq_0 cell DCLK_DIV=2 (60 MHz / 2 = 30 MHz DCLK 50% duty)
set_property CONFIG.DCLK_DIV {2} [get_bd_cells hub75e_panel_seq_0]
puts "\[INFO\] hub75e_panel_seq_0 DCLK_DIV = [get_property CONFIG.DCLK_DIV [get_bd_cells hub75e_panel_seq_0]]"

# 4. validate + save
validate_bd_design
save_bd_design

# 5. wrapper 重生成 (param 改了)
set bd_file [get_files hello_zynq.bd]
make_wrapper -files $bd_file -top -force
update_compile_order -fileset sources_1

# 6. reset + launch
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"

if {[string match "*write_bitstream Complete*" $imp_status]} {
    set xsa_path "../hello_plat/hw/hello_zynq.xsa"
    write_hw_platform -fixed -include_bit -force -file [file normalize $xsa_path]
    puts "\[INFO\] xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
