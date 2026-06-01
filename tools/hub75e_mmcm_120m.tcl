###############################################################################
# 方案 A: Clocking Wizard MMCM 倍频 → hub75e 跑 120 MHz aclk → DCLK 30 MHz
#
# 拓扑:
#   FCLK_CLK1 (75 MHz) → clk_wiz_0 → clk_out1 120 MHz
#   ps7_axi_periph (axi_smc) 仍 75 MHz
#   axi_smc M06 → axi_clock_converter → hub75e (120 MHz domain)
#   hub75e s_axi_aclk = 120 MHz, DCLK_DIV=4 → 30 MHz DCLK
###############################################################################

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# 1. 删旧 hub75e cell + 外部 port (要重连)
catch {delete_bd_objs [get_bd_cells hub75e_panel_seq_0]}
foreach p {hub75e_rgb hub75e_dclk hub75e_lat hub75e_oe hub75e_addr} {
    catch {delete_bd_objs [get_bd_ports $p]}
}
catch {delete_bd_objs [get_bd_cells clk_wiz_0]}
catch {delete_bd_objs [get_bd_cells proc_sys_reset_clk120]}
catch {delete_bd_objs [get_bd_cells axi_clock_converter_0]}
puts "\[INFO\] cleaned old cells"

# 2. 加 Clocking Wizard, FCLK_CLK1 (75 MHz) → 120 MHz
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {75.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {120.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {resetn} \
] [get_bd_cells clk_wiz_0]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins clk_wiz_0/resetn]
puts "\[INFO\] clk_wiz_0 added (75M → 120M)"

# 3. 加 proc_sys_reset for 120 MHz domain
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_clk120
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_clk120/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins proc_sys_reset_clk120/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_clk120/dcm_locked]
puts "\[INFO\] proc_sys_reset_clk120 added"

# 4. 加 axi_clock_converter 跨 75M → 120M
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_0
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.ADDR_WIDTH {16} \
    CONFIG.DATA_WIDTH {32} \
] [get_bd_intf_pins axi_clock_converter_0/S_AXI]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] [get_bd_pins axi_clock_converter_0/s_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_clock_converter_0/s_axi_aresetn]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_clock_converter_0/m_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_clk120/peripheral_aresetn] [get_bd_pins axi_clock_converter_0/m_axi_aresetn]
puts "\[INFO\] axi_clock_converter_0 added"

# 5. 重新 create hub75e_panel_seq_v2 cell
create_bd_cell -type module -reference hub75e_panel_seq_v2 hub75e_panel_seq_0
# 连 AXI 走 clock converter
disconnect_bd_intf_net [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_smc/M06_AXI]]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M06_AXI] [get_bd_intf_pins axi_clock_converter_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_clock_converter_0/M_AXI] [get_bd_intf_pins hub75e_panel_seq_0/s_axi]
# hub75e 用 120 MHz domain
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins hub75e_panel_seq_0/s_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_clk120/peripheral_aresetn] [get_bd_pins hub75e_panel_seq_0/s_axi_aresetn]
puts "\[INFO\] hub75e_panel_seq_0 cell created, 接 120 MHz domain"

# 6. 暴露外部 panel port
foreach {pin port_name port_width} {
    hub75e_rgb_out  hub75e_rgb   6
    hub75e_dclk_out hub75e_dclk  1
    hub75e_lat_out  hub75e_lat   1
    hub75e_oe_out   hub75e_oe    1
    hub75e_addr_out hub75e_addr  5
} {
    if {$port_width == 1} {
        create_bd_port -dir O $port_name
    } else {
        create_bd_port -dir O -from [expr $port_width - 1] -to 0 $port_name
    }
    connect_bd_net [get_bd_pins hub75e_panel_seq_0/$pin] [get_bd_ports $port_name]
}
puts "\[INFO\] external ports created"

# 7. 重 assign address (从 axi_clock_converter 视角)
catch {delete_bd_objs [get_bd_addr_segs -of_objects [get_bd_cells hub75e_panel_seq_0]]}
assign_bd_address -target_address_space /processing_system7_0/Data \
                  [get_bd_addr_segs hub75e_panel_seq_0/s_axi/reg0] \
                  -offset 0x40020000 -range 64K -force

# 8. validate + save
validate_bd_design
save_bd_design

# 9. wrapper 重生成
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 删旧 wrapper 跟旧 BD ip cache
set old_w [get_files -quiet -of_objects [get_filesets sources_1] "*imports/hdl/hello_zynq_wrapper.v"]
foreach w $old_w { remove_files -fileset sources_1 $w }

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
