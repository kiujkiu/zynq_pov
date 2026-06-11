###############################################################################
# 回退方案: 删 MMCM + axi_clock_converter, hub75e 直接接 FCLK0 75MHz
#   DCLK_DIV=3 → DCLK 25 MHz (满足 FM6124 ≥ 20ns TWCLK)
###############################################################################

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# 1. disconnect M06 AXI (从 clock_converter 那边)
catch {disconnect_bd_intf_net [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_smc/M06_AXI]]}
catch {disconnect_bd_intf_net [get_bd_intf_nets -of_objects [get_bd_intf_pins hub75e_panel_seq_0/s_axi]]}

# 2. 删 MMCM + clock_converter + proc_sys_reset_clk120
catch {delete_bd_objs [get_bd_cells axi_clock_converter_0]}
catch {delete_bd_objs [get_bd_cells proc_sys_reset_clk120]}
catch {delete_bd_objs [get_bd_cells clk_wiz_0]}
puts "\[INFO\] MMCM + clock_converter deleted"

# 3. hub75e 直接接 FCLK1 75M (axi_smc M06 已经接 FCLK1, 跟 M06 同 domain)
connect_bd_intf_net [get_bd_intf_pins axi_smc/M06_AXI] [get_bd_intf_pins hub75e_panel_seq_0/s_axi]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] [get_bd_pins hub75e_panel_seq_0/s_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins hub75e_panel_seq_0/s_axi_aresetn]
# 显式设 s_axi FREQ_HZ = 75M, 避免 default 50M
set_property -dict [list CONFIG.FREQ_HZ {75000000}] [get_bd_intf_pins hub75e_panel_seq_0/s_axi]
puts "\[INFO\] hub75e reconnected to FCLK1 75 MHz direct"

# 4. 重 assign address
catch {delete_bd_objs [get_bd_addr_segs -of_objects [get_bd_cells hub75e_panel_seq_0]]}
assign_bd_address -target_address_space /processing_system7_0/Data \
                  [get_bd_addr_segs hub75e_panel_seq_0/s_axi/reg0] \
                  -offset 0x40020000 -range 64K -force

# 5. validate + save
validate_bd_design
save_bd_design

# 6. wrapper 重生
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
}
