# bd_4pov_and_1080p.tcl - 合并 4 路并行 pov + 1080p30 HDMI 升级.
# 一次 Vivado 重建搞定两件事.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"
set ip_repo  "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"

puts "=== Open project ==="
open_project $proj_xpr
set existing_repos [get_property ip_repo_paths [current_project]]
if {[lsearch -exact $existing_repos $ip_repo] < 0} {
    set_property ip_repo_paths [concat $existing_repos $ip_repo] [current_project]
}
update_ip_catalog
open_bd_design [get_files ${bd_name}.bd]

# --- 升级被锁的 IP ---
set locked_ips [get_ips -filter "IS_LOCKED==1"]
if {[llength $locked_ips] > 0} {
    puts "Upgrading locked IPs: $locked_ips"
    upgrade_ip $locked_ips
}

# ==========================================================================
# PART 1: 4 路并行 pov
# ==========================================================================

puts "=== Enable S_AXI_HP2 ==="
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP2 {1} \
] [get_bd_cells /processing_system7_0]

foreach i {1 2 3} {
    set inst "pov_project_$i"
    if {![llength [get_bd_cells -quiet $inst]]} {
        puts "Add $inst"
        create_bd_cell -type ip -vlnv povlab:user:pov_project:1.0 $inst
    }
}

# axi_smc: 4M -> 7M
set_property -dict [list CONFIG.NUM_MI {7}] [get_bd_cells axi_smc]

# axi_smc_pov_hp: 2S -> 4S, 容纳 pov0+pov1 的 gmem0/1
set_property -dict [list \
    CONFIG.NUM_SI {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells axi_smc_pov_hp]

# 新 smc_pov_hp2: 4S/1M 给 pov2+pov3 → HP2
if {![llength [get_bd_cells -quiet smc_pov_hp2]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_pov_hp2
}
set_property -dict [list \
    CONFIG.NUM_SI {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells smc_pov_hp2]

# 控制总线连接 (新 pov1/2/3 的 s_axi_control)
foreach {i mi} {1 M04_AXI 2 M05_AXI 3 M06_AXI} {
    set src [get_bd_intf_pins axi_smc/$mi]
    set dst [get_bd_intf_pins pov_project_$i/s_axi_control]
    # 如果已有连接, 跳过
    if {![llength [get_bd_intf_nets -of_objects $dst]]} {
        connect_bd_intf_net $src $dst
    }
}

# 数据总线 pov1 → hp1 smc (S02/S03)
if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins pov_project_1/m_axi_gmem0]]]} {
    connect_bd_intf_net [get_bd_intf_pins pov_project_1/m_axi_gmem0] \
                        [get_bd_intf_pins axi_smc_pov_hp/S02_AXI]
}
if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins pov_project_1/m_axi_gmem1]]]} {
    connect_bd_intf_net [get_bd_intf_pins pov_project_1/m_axi_gmem1] \
                        [get_bd_intf_pins axi_smc_pov_hp/S03_AXI]
}

# 数据总线 pov2/3 → hp2 smc
foreach {i si} {2 S00_AXI 3 S02_AXI} {
    set sj [string replace $si 2 2 [expr {[string index $si 2] + 1}]]
    if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins pov_project_$i/m_axi_gmem0]]]} {
        connect_bd_intf_net [get_bd_intf_pins pov_project_$i/m_axi_gmem0] \
                            [get_bd_intf_pins smc_pov_hp2/$si]
    }
    if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins pov_project_$i/m_axi_gmem1]]]} {
        connect_bd_intf_net [get_bd_intf_pins pov_project_$i/m_axi_gmem1] \
                            [get_bd_intf_pins smc_pov_hp2/$sj]
    }
}

# smc_pov_hp2 → HP2
if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins smc_pov_hp2/M00_AXI]]]} {
    connect_bd_intf_net [get_bd_intf_pins smc_pov_hp2/M00_AXI] \
                        [get_bd_intf_pins processing_system7_0/S_AXI_HP2]
}

# 时钟
set fclk3 [get_bd_pins processing_system7_0/FCLK_CLK3]
foreach pin {
    pov_project_1/ap_clk
    pov_project_2/ap_clk
    pov_project_3/ap_clk
    smc_pov_hp2/aclk
    processing_system7_0/S_AXI_HP2_ACLK
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $fclk3 $p
}

# 复位
set rst_pov [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
foreach pin {
    pov_project_1/ap_rst_n
    pov_project_2/ap_rst_n
    pov_project_3/ap_rst_n
    smc_pov_hp2/aresetn
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $rst_pov $p
}

# 地址
foreach {i off} {1 0x43C30000 2 0x43C40000 3 0x43C50000} {
    assign_bd_address -offset $off -range 64K \
        [get_bd_addr_segs pov_project_$i/s_axi_control/Reg] -force
}
assign_bd_address -offset 0x00000000 -range 1G \
    [get_bd_addr_segs processing_system7_0/S_AXI_HP2/HP2_DDR_LOWOCM] -force

# ==========================================================================
# PART 2: 1080p30 HDMI 升级
# ==========================================================================

puts "=== Configure VTC for 1080p@30 ==="
set_property -dict [list \
    CONFIG.GEN_HACTIVE_SIZE  {1920} \
    CONFIG.GEN_HFRONTPORCH_SIZE {88} \
    CONFIG.GEN_HSYNC_SIZE {44} \
    CONFIG.GEN_HBACKPORCH_SIZE {148} \
    CONFIG.GEN_VACTIVE_SIZE  {1080} \
    CONFIG.GEN_VFRONTPORCH_SIZE {4} \
    CONFIG.GEN_VSYNC_SIZE {5} \
    CONFIG.GEN_VBACKPORCH_SIZE {36} \
    CONFIG.GEN_F0_VBLANK_HSTART {1081} \
    CONFIG.GEN_F0_VBLANK_HEND {1} \
    CONFIG.GEN_F0_VSYNC_VSTART {1084} \
    CONFIG.GEN_F0_VSYNC_VEND {1089} \
    CONFIG.GEN_F0_VSYNC_HSTART {1921} \
    CONFIG.GEN_F0_VSYNC_HEND {1921} \
    CONFIG.GEN_F0_VFRAME_SIZE {1125} \
    CONFIG.GEN_F0_VACTIVE_START {41} \
    CONFIG.GEN_F0_VCHROMA_START {41} \
    CONFIG.GEN_HACTIVE_START {192} \
    CONFIG.GEN_HFRAME_SIZE {2200} \
] [get_bd_cells v_tc_0]

puts "=== VDMA linebuffer depth 512 -> 1024 (for 1920 width) ==="
set_property -dict [list \
    CONFIG.c_mm2s_linebuffer_depth {1024} \
] [get_bd_cells axi_vdma_0]

# ==========================================================================
# Validate & build
# ==========================================================================

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Build bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
