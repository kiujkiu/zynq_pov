# bd_swap_to_mesh_slice.tcl — 替换 4× voxel IP 为 mesh_slice_render single IP
#
# Phase 9.5 ADR-001 选项 B 验证:
# - 移除 pov_project_batch_0/1/2/3 + sc_pov_axilite
# - 添加 mesh_slice_render (povlab:user:mesh_slice_render:1.0)
# - axi_smc_pov_hp NUM_SI 8→4 (mesh 4 m_axi gmem0/1/2/3)
# - axi_smc/M03 直连 mesh/s_axi_control (撤销 sc_pov_axilite fan-out)
# - 综合 + impl + 拿真实 timing/utilization vs HLS estimate (97% LUT)
#
# 跑法:
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch \
#     -source D:\workspace\zynq_pov\tools\bd_swap_to_mesh_slice.tcl -nojournal

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

# 1) Add mesh_slice IP path to IP repo (folder containing component.xml).
#    Keep existing voxel IP repo (proj_pov/solution1/impl/ip) so we can
#    restore later if mesh fails.
set existing_repos [get_property ip_repo_paths [current_project]]
set new_repos $existing_repos
lappend new_repos D:/workspace/zynq_pov/hls_proj/mesh_slice_ip
set_property ip_repo_paths $new_repos [current_project]
update_ip_catalog -rebuild

# 2) Open BD
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# 3) 删除 4× voxel IP + sc_pov_axilite
foreach c {pov_project_batch_0 pov_project_batch_1 pov_project_batch_2 pov_project_batch_3 sc_pov_axilite} {
    set cell [get_bd_cells -quiet $c]
    if {$cell ne ""} {
        catch { delete_bd_objs $cell }
        puts "deleted $c"
    }
}

# 4) axi_smc_pov_hp NUM_SI 8 → 4 (mesh 4 m_axi)
set_property CONFIG.NUM_SI 4 [get_bd_cells axi_smc_pov_hp]

# 5) Add mesh_slice_render IP
if {[get_bd_cells -quiet mesh_slice_render_0] eq ""} {
    create_bd_cell -type ip -vlnv povlab:user:mesh_slice_render:1.0 mesh_slice_render_0
    puts "added mesh_slice_render_0"
}

# 6) Wire clock + reset (FCLK_CLK3 / proc_sys_reset_pov, same domain as deleted IP0)
catch { connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK3] \
    [get_bd_pins mesh_slice_render_0/ap_clk] }
catch { connect_bd_net [get_bd_pins proc_sys_reset_pov/peripheral_aresetn] \
    [get_bd_pins mesh_slice_render_0/ap_rst_n] }

# 7) Connect 4 m_axi to axi_smc_pov_hp S00..S03 → HP1
foreach idx {0 1 2 3} {
    set s [format "S%02d_AXI" $idx]
    catch { connect_bd_intf_net [get_bd_intf_pins mesh_slice_render_0/m_axi_gmem$idx] \
        [get_bd_intf_pins axi_smc_pov_hp/$s] }
    catch { connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK3] \
        [get_bd_pins axi_smc_pov_hp/[format "S%02d_ACLK" $idx]] }
    catch { connect_bd_net [get_bd_pins proc_sys_reset_pov/peripheral_aresetn] \
        [get_bd_pins axi_smc_pov_hp/[format "S%02d_ARESETN" $idx]] }
}

# 8) Connect s_axi_control to axi_smc/M03 (where old IP0 was)
catch { connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] \
    [get_bd_intf_pins mesh_slice_render_0/s_axi_control] }

# 9) Address map
catch { assign_bd_address [get_bd_addr_segs mesh_slice_render_0/s_axi_control/Reg] }
foreach mem {gmem0 gmem1 gmem2 gmem3} {
    catch {
        set as [get_bd_addr_spaces mesh_slice_render_0/Data_m_axi_$mem]
        assign_bd_address -target_address_space $as \
            [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM]
    }
}

# 10) Validate + save + generate
validate_bd_design
save_bd_design
generate_target all $bd_file

# 11) Synth + impl + bit
catch { reset_run synth_1 }
catch { reset_run impl_1 }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "DONE: mesh_slice swap synth complete"
exit 0
