# 集成新 HLS pov_proj IP: drop-in 替换旧 pov_project_batch_0, 复用 HP1/AXI-Lite/reset 基础设施.
# 改完 validate + save, 不 build (审完单独建).
open_project 02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

# 1. IP catalog: 追加 hls_pov/ip_repo (保留原有 vivado-library/rgb2dvi, 否则 hdmi_tmds 找不到锁 BD!)
set cur [get_property ip_repo_paths [current_project]]
set_property ip_repo_paths [concat $cur [list "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/hls_pov/ip_repo"]] [current_project]
puts "== ip_repo_paths: [get_property ip_repo_paths [current_project]] =="
update_ip_catalog -rebuild
puts "== catalog: [get_ipdefs -quiet *pov_proj*] =="

open_bd_design [get_files hello_zynq.bd]

# 2. 删旧 pov_project_batch_0 (确认不可用; 释放资源, 基础设施保留)
delete_bd_objs [get_bd_cells pov_project_batch_0]
puts "== deleted pov_project_batch_0 =="

# 3. 加新 pov_proj_0
create_bd_cell -type ip -vlnv povlab:user:pov_proj:1.0 pov_proj_0
puts "== new pov_proj_0 接口 =="
foreach p [get_bd_intf_pins /pov_proj_0/*] { puts "    $p" }
foreach p [get_bd_pins -quiet /pov_proj_0/ap_*] { puts "    $p" }

# 4. 连接 (复用旧基础设施: axi_smc_pov_hp→HP1, sc_pov_axilite, proc_sys_reset_pov@FCLK3)
connect_bd_intf_net [get_bd_intf_pins pov_proj_0/m_axi_gmem0]  [get_bd_intf_pins axi_smc_pov_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_proj_0/m_axi_gmem1]  [get_bd_intf_pins axi_smc_pov_hp/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_proj_0/s_axi_control] [get_bd_intf_pins sc_pov_axilite/M00_AXI]
connect_bd_net [get_bd_pins pov_proj_0/ap_clk]   [get_bd_pins processing_system7_0/FCLK_CLK3]
connect_bd_net [get_bd_pins pov_proj_0/ap_rst_n] [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
puts "== connected =="

# 5. 地址: control 复用 0x43C20000, gmem0/1 → HP1 DDR 全段
assign_bd_address -offset 0x43C20000 -range 0x10000 [get_bd_addr_segs pov_proj_0/s_axi_control/Reg]
catch { assign_bd_address [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM] -target_address_space [get_bd_addr_spaces pov_proj_0/Data_m_axi_gmem0] }
catch { assign_bd_address [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM] -target_address_space [get_bd_addr_spaces pov_proj_0/Data_m_axi_gmem1] }
catch { assign_bd_address }   ;# 兜底自动分配剩余
puts "== 地址分配 =="
foreach a [get_bd_addr_segs -of_objects [get_bd_cells pov_proj_0]] { puts "    $a off=[get_property -quiet OFFSET $a] rng=[get_property -quiet RANGE $a]" }
catch { puts "    control: [get_property OFFSET [get_bd_addr_segs processing_system7_0/Data/SEG_pov_proj_0_Reg]]" }

# 6. validate + save
set vrc [catch { validate_bd_design } verr]
puts "== VALIDATE: [expr {$vrc==0 ? {OK} : {FAIL}}] =="
if {$vrc != 0} { puts "VALIDATE_ERR: $verr" }
save_bd_design
puts "== SAVED. (未 build) =="
close_project
exit 0
