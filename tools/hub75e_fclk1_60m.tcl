###############################################################################
# 改 PS7 FCLK1 75M → 60M (DCLK_DIV=2 时 DCLK = 60/2 = 30M spec 内)
# 用 set_property 让 Vivado 自己 propagate
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# Unlock + upgrade IPs first (manual xci edit 后必做)
puts "\[INFO\] upgrade_ip all to unlock"
catch {upgrade_ip [get_ips]}

# Set FCLK1 freq
puts "\[INFO\] setting PS7 FCLK1 = 60 MHz"
set_property -dict [list CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {60}] [get_bd_cells processing_system7_0]

# Validate + save
validate_bd_design
save_bd_design

set fclk1 [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]
puts "\[INFO\] PS7 FCLK1 = $fclk1 MHz"

# Reset + regenerate IP outputs
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
