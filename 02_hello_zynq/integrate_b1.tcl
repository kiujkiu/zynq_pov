# 集成 B1 pov_render_full (点云直进FPGA): 替换 pov_proj_0, 3 m_axi → HP1, 复用基础设施.
# ⚠ ip_repo_paths 必须 concat 追加 (保留 vivado-library/rgb2dvi, 否则 hdmi_tmds 锁 BD).
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
set cur [get_property ip_repo_paths [current_project]]
set_property ip_repo_paths [concat $cur [list "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/hls_pov/ip_repo"]] [current_project]
update_ip_catalog -rebuild
puts "== catalog: [get_ipdefs -quiet *pov_render_full*] =="

open_bd_design [get_files hello_zynq.bd]

# 删旧 pov_proj_0 (B1 取代它)
catch { delete_bd_objs [get_bd_cells pov_proj_0] }
puts "== deleted pov_proj_0 =="

# 加 B1
create_bd_cell -type ip -vlnv povlab:user:pov_render_full:1.0 pov_render_full_0
puts "== B1 接口 =="
foreach p [get_bd_intf_pins /pov_render_full_0/*] { puts "    $p" }
foreach p [get_bd_pins -quiet /pov_render_full_0/ap_*] { puts "    $p" }

# 连 3 m_axi → axi_smc_pov_hp S00/S01/S02 → HP1; control → sc_pov_axilite M00
connect_bd_intf_net [get_bd_intf_pins pov_render_full_0/m_axi_gmem_pts] [get_bd_intf_pins axi_smc_pov_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_render_full_0/m_axi_gmem_vox] [get_bd_intf_pins axi_smc_pov_hp/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_render_full_0/m_axi_gmem_out] [get_bd_intf_pins axi_smc_pov_hp/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_render_full_0/s_axi_control]  [get_bd_intf_pins sc_pov_axilite/M00_AXI]
connect_bd_net [get_bd_pins pov_render_full_0/ap_clk]   [get_bd_pins processing_system7_0/FCLK_CLK3]
connect_bd_net [get_bd_pins pov_render_full_0/ap_rst_n] [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
puts "== connected =="

# 地址: control 0x43C20000; 3 master → HP1 DDR
assign_bd_address -offset 0x43C20000 -range 0x10000 [get_bd_addr_segs pov_render_full_0/s_axi_control/Reg]
foreach sp {Data_m_axi_gmem_pts Data_m_axi_gmem_vox Data_m_axi_gmem_out} {
    catch { assign_bd_address [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM] -target_address_space [get_bd_addr_spaces pov_render_full_0/$sp] }
}
catch { assign_bd_address }
puts "== 地址 =="
foreach a [get_bd_addr_segs -of_objects [get_bd_cells pov_render_full_0]] { puts "    $a off=[get_property -quiet OFFSET $a] rng=[get_property -quiet RANGE $a]" }
catch { puts "    control: [get_property OFFSET [get_bd_addr_segs processing_system7_0/Data/SEG_pov_render_full_0_Reg]]" }

set vrc [catch { validate_bd_design } verr]
puts "== VALIDATE: [expr {$vrc==0 ? {OK} : {FAIL}}] =="
if {$vrc != 0} { puts "VERR: $verr" }
save_bd_design
puts "== SAVED (未 build) =="
close_project
exit 0
