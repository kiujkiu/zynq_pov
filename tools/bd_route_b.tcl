# bd_route_b.tcl
# 路线 B: 用 PS 直出 FCLK_CLK1 代替 clk_wiz_0
# 所有时钟域统一到 FCLK_CLK1, 不再跨时钟域

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# -------- Step 1: 启用 FCLK_CLK1 @ 74.25 MHz --------
puts "=== Step 1: Enable FCLK_CLK1 at 74.25 MHz ==="
set_property -dict [list \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {74.25} \
    CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL} \
] [get_bd_cells /processing_system7_0]
set actual_fclk1 [get_property CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells /processing_system7_0]]
puts "Actual FCLK_CLK1 frequency: $actual_fclk1 MHz"

# -------- Step 2: 删除 clk_wiz_0 (它相关的所有网会自动被清) --------
puts "=== Step 2: Delete clk_wiz_0 ==="
delete_bd_objs [get_bd_cells clk_wiz_0]

# -------- Step 3: 所有时钟端口都连到 FCLK_CLK1 --------
puts "=== Step 3: Wire all clocks to FCLK_CLK1 ==="
set fclk1 [get_bd_pins processing_system7_0/FCLK_CLK1]
set fclk1_targets {
    processing_system7_0/M_AXI_GP0_ACLK
    axi_smc/aclk
    axi_gpio_0/s_axi_aclk
    proc_sys_reset_0/slowest_sync_clk
    v_tpg_0/ap_clk
    v_tc_0/clk
    v_tc_0/s_axi_aclk
    v_axi4s_vid_out_0/aclk
    v_axi4s_vid_out_0/vid_io_out_clk
    rgb2dvi_0/PixelClk
}
foreach pin $fclk1_targets {
    set p [get_bd_pins $pin]
    if {[llength $p] == 0} continue
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $fclk1 $p
}

# -------- Step 4: SmartConnect 恢复 3 MI, 重连 v_tc 和 v_tpg --------
puts "=== Step 4: Restore SmartConnect -> v_tc, v_tpg ==="
set_property CONFIG.NUM_MI {3} [get_bd_cells /axi_smc]
# AXI-Lite 接口重连
if {[llength [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_smc/M01_AXI]]] == 0} {
    connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins v_tc_0/ctrl]
}
if {[llength [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_smc/M02_AXI]]] == 0} {
    connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] [get_bd_intf_pins v_tpg_0/s_axi_CTRL]
}

# -------- Step 5: 视频 IP 的复位重连到 proc_sys_reset_0 --------
puts "=== Step 5: Wire video IP aresetn ==="
set rst_pin [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
foreach pin {
    v_tpg_0/ap_rst_n
    v_tc_0/resetn
    v_tc_0/s_axi_aresetn
    v_axi4s_vid_out_0/aresetn
    rgb2dvi_0/aRst_n
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $rst_pin $p
}

# -------- Step 6: 地址映射 --------
puts "=== Step 6: Assign addresses ==="
assign_bd_address -offset 0x43C00000 -range 64K \
    [get_bd_addr_segs {v_tc_0/ctrl/Reg}] -force
assign_bd_address -offset 0x43C10000 -range 64K \
    [get_bd_addr_segs {v_tpg_0/s_axi_CTRL/Reg}] -force

# -------- Step 7: validate & save --------
puts "=== Step 7: Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Synth + Impl + Bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth_1 status: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl_1 status: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
