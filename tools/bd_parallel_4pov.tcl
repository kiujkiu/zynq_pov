# bd_parallel_4pov.tcl
# 在现有 BD 上扩展到 4 路并行 pov_project IP.
#
# 架构:
#   GP0 → axi_smc (NUM_MI=7) → {gpio, vtc, vdma, pov0..3.ctrl}
#   pov0/1 的 gmem0/1 → smc_pov_hp1 (4S/1M) → HP1
#   pov2/3 的 gmem0/1 → smc_pov_hp2 (4S/1M) → HP2
#   (axi_smc_pov_hp 被重命名/改名成 smc_pov_hp1)
#
# 控制寄存器地址:
#   pov0 @ 0x43C20000 (不动)
#   pov1 @ 0x43C30000
#   pov2 @ 0x43C40000
#   pov3 @ 0x43C50000

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

# --- 先升级被锁的老 IP (如果 HLS 重综合过) ---
set locked_ips [get_ips -filter "IS_LOCKED==1"]
if {[llength $locked_ips] > 0} {
    puts "Upgrading locked IPs: $locked_ips"
    upgrade_ip $locked_ips
    export_ip_user_files -of_objects $locked_ips -no_script -sync -force -quiet
}

# --- PS 启用 HP2 (HP1 已有, HP2 给 pov2/3) ---
puts "=== PS enable S_AXI_HP2 ==="
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP2 {1} \
] [get_bd_cells /processing_system7_0]

# --- 实例化 pov_project_1, _2, _3 ---
foreach i {1 2 3} {
    set inst "pov_project_$i"
    puts "=== Add $inst ==="
    if {![llength [get_bd_cells -quiet $inst]]} {
        create_bd_cell -type ip -vlnv povlab:user:pov_project:1.0 $inst
    }
}

# --- 扩展 axi_smc 到 7 M (原 4 + 3 新 pov ctrl) ---
puts "=== Expand axi_smc to 7 masters ==="
set_property -dict [list \
    CONFIG.NUM_MI {7} \
] [get_bd_cells axi_smc]

# --- 重命名 axi_smc_pov_hp → smc_pov_hp1; 扩展到 4S/1M ---
# 如果旧 smc 还叫 axi_smc_pov_hp, 改名 (optional, skip if already renamed)
if {[llength [get_bd_cells -quiet axi_smc_pov_hp]]} {
    # 尝试就地改配置
    set_property -dict [list \
        CONFIG.NUM_SI {4} \
        CONFIG.NUM_MI {1} \
        CONFIG.NUM_CLKS {1} \
    ] [get_bd_cells axi_smc_pov_hp]
}

# --- 新 smartconnect smc_pov_hp2 (4S→1M) 给 pov2/3 走 HP2 ---
puts "=== Add smc_pov_hp2 ==="
if {![llength [get_bd_cells -quiet smc_pov_hp2]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_pov_hp2
}
set_property -dict [list \
    CONFIG.NUM_SI {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells smc_pov_hp2]

# --- 连线: 4 个 pov ctrl ---
puts "=== Wire control buses ==="
# pov_project_0 的 s_axi_control 已连到 axi_smc/M03, 不动
# pov_project_1..3 接到 M04..M06
foreach {i mi} {1 M04_AXI 2 M05_AXI 3 M06_AXI} {
    connect_bd_intf_net [get_bd_intf_pins axi_smc/$mi] \
                        [get_bd_intf_pins pov_project_$i/s_axi_control]
}

# --- 连线: pov0/1 的 gmem0/1 → smc_pov_hp1 (已原名 axi_smc_pov_hp) ---
puts "=== Wire pov0/1 data buses to HP1 smc ==="
# pov0 已连 S00, S01 (旧), 保留; pov1 新连 S02, S03
connect_bd_intf_net [get_bd_intf_pins pov_project_1/m_axi_gmem0] \
                    [get_bd_intf_pins axi_smc_pov_hp/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_project_1/m_axi_gmem1] \
                    [get_bd_intf_pins axi_smc_pov_hp/S03_AXI]

# --- 连线: pov2/3 的 gmem0/1 → smc_pov_hp2 ---
puts "=== Wire pov2/3 data buses to HP2 smc ==="
connect_bd_intf_net [get_bd_intf_pins pov_project_2/m_axi_gmem0] \
                    [get_bd_intf_pins smc_pov_hp2/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_project_2/m_axi_gmem1] \
                    [get_bd_intf_pins smc_pov_hp2/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_project_3/m_axi_gmem0] \
                    [get_bd_intf_pins smc_pov_hp2/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_project_3/m_axi_gmem1] \
                    [get_bd_intf_pins smc_pov_hp2/S03_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_pov_hp2/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP2]

# --- 时钟: 所有 pov 路径都在 FCLK_CLK3 (150 MHz) ---
puts "=== Wire clocks (FCLK_CLK3 for new pov) ==="
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

# --- 复位: 用 proc_sys_reset_pov (已存在) ---
puts "=== Wire resets ==="
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

# --- 地址分配 ---
puts "=== Assign addresses ==="
assign_bd_address -offset 0x43C30000 -range 64K \
    [get_bd_addr_segs {pov_project_1/s_axi_control/Reg}] -force
assign_bd_address -offset 0x43C40000 -range 64K \
    [get_bd_addr_segs {pov_project_2/s_axi_control/Reg}] -force
assign_bd_address -offset 0x43C50000 -range 64K \
    [get_bd_addr_segs {pov_project_3/s_axi_control/Reg}] -force
# HP2 的 DDR 映射
assign_bd_address -offset 0x00000000 -range 1G \
    [get_bd_addr_segs {processing_system7_0/S_AXI_HP2/HP2_DDR_LOWOCM}] -force

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
puts "=== DONE (4-pov parallel) ==="
exit 0
