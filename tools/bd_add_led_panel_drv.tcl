# bd_add_led_panel_drv.tcl — 集成 led_panel_drv IP 到 BD (阶段 3)
#
# Phase 9.5+ LED panel 真硬件 bring-up 任务. 待 panel 到货 + ARM bit-bang
# baseline 验证 + PL Verilog IP synth 通过后再跑.
#
# 跑前提:
#   1. hls_proj/led_panel_drv/ 含 packaged IP zip (povlab:user:led_panel_drv:1.0)
#   2. IP 解压到 hls_proj/led_panel_drv_ip/ (含 component.xml)
#   3. FPC pinout 已确认 → 知道 panel signal 接 FPGA 哪些 PL pin
#   4. 现 BD 在 phase9.5-task-I-dual-core 集成基础 (含 4× pov_project_batch + dual-core)
#
# 跑法 (Windows):
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch \
#     -source D:\workspace\zynq_pov\tools\bd_add_led_panel_drv.tcl -nojournal

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

# 1) Add led_panel_drv IP repo
set existing_repos [get_property ip_repo_paths [current_project]]
set new_repos $existing_repos
lappend new_repos D:/workspace/zynq_pov/hls_proj/led_panel_drv_ip
set_property ip_repo_paths $new_repos [current_project]
update_ip_catalog -rebuild

# 2) Open BD
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# 3) Add led_panel_drv IP
if {[get_bd_cells -quiet led_panel_drv_0] eq ""} {
    create_bd_cell -type ip -vlnv povlab:user:led_panel_drv:1.0 led_panel_drv_0
    puts "added led_panel_drv_0"
}

# 4) Wire clock + reset (FCLK_CLK3 same domain as voxel IPs)
catch { connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK3] \
    [get_bd_pins led_panel_drv_0/ap_clk] }
catch { connect_bd_net [get_bd_pins proc_sys_reset_pov/peripheral_aresetn] \
    [get_bd_pins led_panel_drv_0/ap_rst_n] }

# 5) AXI-Lite control: connect via existing sc_pov_axilite (or extend its NUM_MI to 5)
#    现 sc_pov_axilite NUM_MI=4 (M00..M03 给 4× pov_project_batch).
#    扩到 NUM_MI=5, M04 → led_panel_drv_0/s_axi_control
if {[get_bd_cells -quiet sc_pov_axilite] ne ""} {
    set_property CONFIG.NUM_MI 5 [get_bd_cells sc_pov_axilite]
    catch { connect_bd_intf_net [get_bd_intf_pins sc_pov_axilite/M04_AXI] \
        [get_bd_intf_pins led_panel_drv_0/s_axi_control] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
        [get_bd_pins sc_pov_axilite/M04_ACLK] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] \
        [get_bd_pins sc_pov_axilite/M04_ARESETN] }
}

# 6) AXI-Stream input (frame data from voxel slice ring buffer / DMA)
#    Option A: 通过 axi_smc_pov_hp 共享 HP1, NUM_SI 8 → 9
#    Option B: 加新 smc led_smc_hp 给 HP3 (HP2/HP3 现空闲)
#    选 Option B (HP3) 不影响现 voxel 4× IP 路径
if {[get_bd_cells -quiet led_smc_hp] eq ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 led_smc_hp
    set_property CONFIG.NUM_SI 1 [get_bd_cells led_smc_hp]
    set_property CONFIG.NUM_MI 1 [get_bd_cells led_smc_hp]
    set_property CONFIG.NUM_CLKS 1 [get_bd_cells led_smc_hp]
    # Connect IP m_axi_fb → led_smc_hp/S00 → HP3
    catch { connect_bd_intf_net [get_bd_intf_pins led_panel_drv_0/m_axi_fb] \
        [get_bd_intf_pins led_smc_hp/S00_AXI] }
    catch { connect_bd_intf_net [get_bd_intf_pins led_smc_hp/M00_AXI] \
        [get_bd_intf_pins processing_system7_0/S_AXI_HP3] }
    # PS HP3 enable (if not already)
    set_property -dict [list CONFIG.PCW_USE_S_AXI_HP3 {1}] [get_bd_cells processing_system7_0]
    # Clock + reset
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
        [get_bd_pins led_smc_hp/aclk] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] \
        [get_bd_pins led_smc_hp/aresetn] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
        [get_bd_pins processing_system7_0/S_AXI_HP3_ACLK] }
}

# 7) Panel signal outputs → external pins (PL bank 33 / 35 GPIO 扩展接口)
#    需要 user 提供 FPC pinout, 这里 placeholder 创建 external port:
foreach sig {dclk le row sdi_0 sdi_1 sdi_2 sdi_3 dclk_row rclk sdi_row} {
    if {[get_bd_ports -quiet panel_$sig] eq ""} {
        create_bd_port -dir O panel_$sig
        catch { connect_bd_net [get_bd_pins led_panel_drv_0/$sig] \
            [get_bd_ports panel_$sig] }
    }
}

# 8) Address map
catch { assign_bd_address [get_bd_addr_segs led_panel_drv_0/s_axi_control/Reg] }
catch {
    set as [get_bd_addr_spaces led_panel_drv_0/Data_m_axi_fb]
    assign_bd_address -target_address_space $as \
        [get_bd_addr_segs processing_system7_0/S_AXI_HP3/HP3_DDR_LOWOCM]
}

# 9) Validate + save + generate
validate_bd_design
save_bd_design
generate_target all $bd_file

# 10) XDC: 设置 panel 信号物理引脚
#     需要 user 提供 FPC pinout, 然后填到 xdc constraint:
#     set_property PACKAGE_PIN <PIN> [get_ports panel_dclk]
#     ...

# 11) 综合 (待 user 确认 XDC 后)
# catch { reset_run synth_1 }
# catch { reset_run impl_1 }
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1

puts "DONE: led_panel_drv added to BD. Next: fill XDC + run synth+impl."
exit 0
