# bd_add_pov_ip.tcl
# 把 HLS 生成的 pov_project IP 挂到 BD 上:
#   PS M_AXI_GP0 --[axi_smc + 新 M03]--> pov_project.s_axi_control (控制寄存器, AXI-Lite)
#   pov_project.m_axi_gmem0 (读模型, 128b) --+
#                                             +--[axi_smc_pov_hp]--> PS S_AXI_HP1 --> DDR
#   pov_project.m_axi_gmem1 (写 fb, 32b)   --+
#
# VDMA 保持走 HP0 读 DDR 显示, 不动.
# FCLK_CLK1 (75 MHz) 给 pov_project 用. HLS Fmax 205 MHz, 75MHz 时序有巨大余量.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"
set ip_repo  "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"

puts "=== Open project ==="
open_project $proj_xpr

puts "=== Register IP repo: $ip_repo ==="
set existing_repos [get_property ip_repo_paths [current_project]]
if {[lsearch -exact $existing_repos $ip_repo] < 0} {
    set_property ip_repo_paths [concat $existing_repos $ip_repo] [current_project]
}
update_ip_catalog

open_bd_design [get_files ${bd_name}.bd]

# --- 升级 BD 里已存在的被锁 IP (如果有) ---
puts "=== Upgrade any locked IPs ==="
set locked_ips [get_ips -filter "IS_LOCKED==1"]
if {[llength $locked_ips] > 0} {
    puts "Locked IPs: $locked_ips"
    upgrade_ip $locked_ips
    export_ip_user_files -of_objects $locked_ips -no_script -sync -force -quiet
}

# --- PS: 启用 S_AXI_HP1, 同时开一个 FCLK_CLK3=150 MHz 专门给 pov 用
# (FCLK_CLK1 必须保留 75 MHz 给 rgb2dvi PLL, 改它会让 VCO 越界) ---
puts "=== PS enable S_AXI_HP1 + add FCLK_CLK3 @ 150 MHz for pov ==="
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP1 {1} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {75} \
    CONFIG.PCW_EN_CLK3_PORT {1} \
    CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {150} \
] [get_bd_cells /processing_system7_0]

# --- 实例化 pov_project IP ---
puts "=== Add pov_project IP ==="
if {![llength [get_bd_cells -quiet pov_project_0]]} {
    create_bd_cell -type ip -vlnv povlab:user:pov_project:1.0 pov_project_0
}

# --- 扩展 axi_smc: 原 3 M 加到 4 M, 新 M03 接 pov 控制口 (pov 在 150 MHz 域需要 CDC) ---
puts "=== Expand axi_smc to 4 masters, 2 clocks (FCLK_CLK1 75MHz + FCLK_CLK3 150MHz) ==="
set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.NUM_CLKS {2} \
] [get_bd_cells axi_smc]

# --- 新 SmartConnect: pov 的 2 个 m_axi 都走 HP1 ---
puts "=== Add axi_smc_pov_hp (2S -> 1M) ==="
if {![llength [get_bd_cells -quiet axi_smc_pov_hp]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_pov_hp
}
set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells axi_smc_pov_hp]

# --- 接控制总线: axi_smc/M03 → pov_project_0/s_axi_control ---
puts "=== Wire control bus ==="
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] \
                    [get_bd_intf_pins pov_project_0/s_axi_control]

# axi_smc 的第 2 个 clock (aclk1) 接 FCLK_CLK3, M03 的时钟关联 aclk1
set fclk3_pin [get_bd_pins processing_system7_0/FCLK_CLK3]
set smc_aclk1 [get_bd_pins axi_smc/aclk1]
foreach n [get_bd_nets -of_objects $smc_aclk1] { disconnect_bd_net $n $smc_aclk1 }
connect_bd_net $fclk3_pin $smc_aclk1
# 告诉 smc: M03_AXI 用 aclk1 (FCLK_CLK3)
set_property CONFIG.ASSOCIATED_BUSIF {M03_AXI} [get_bd_pins axi_smc/aclk1]

# --- 接数据路径: pov m_axi_gmem0/gmem1 → axi_smc_pov_hp → HP1 ---
puts "=== Wire data path ==="
connect_bd_intf_net [get_bd_intf_pins pov_project_0/m_axi_gmem0] \
                    [get_bd_intf_pins axi_smc_pov_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins pov_project_0/m_axi_gmem1] \
                    [get_bd_intf_pins axi_smc_pov_hp/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_pov_hp/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP1]

# --- 时钟: pov 路径 (pov_project + axi_smc_pov_hp + HP1 port) 全部走 FCLK_CLK3=150 MHz
# axi_smc (控制路径, 挂 pov s_axi_control) 仍然在 FCLK_CLK1=75 MHz, smc 自动做 CDC ---
puts "=== Wire clocks (pov path on FCLK_CLK3 150 MHz) ==="
set fclk3 [get_bd_pins processing_system7_0/FCLK_CLK3]
foreach pin {
    pov_project_0/ap_clk
    axi_smc_pov_hp/aclk
    processing_system7_0/S_AXI_HP1_ACLK
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $fclk3 $p
}

# --- 复位: 给 FCLK_CLK3 域加一个独立 proc_sys_reset ---
puts "=== Add proc_sys_reset_pov for FCLK_CLK3 domain ==="
if {![llength [get_bd_cells -quiet proc_sys_reset_pov]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_pov
}
set pov_rst_cell [get_bd_cells proc_sys_reset_pov]
set fclk3 [get_bd_pins processing_system7_0/FCLK_CLK3]
set fclk_rst0 [get_bd_pins processing_system7_0/FCLK_RESET0_N]
# 接 slowest_sync_clk + ext_reset_in
foreach {pin src} [list \
    proc_sys_reset_pov/slowest_sync_clk   $fclk3 \
    proc_sys_reset_pov/ext_reset_in       $fclk_rst0 \
] {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $src $p
}

puts "=== Wire resets ==="
set rst_pov [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
foreach pin {
    pov_project_0/ap_rst_n
    axi_smc_pov_hp/aresetn
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $rst_pov $p
}

# interrupt 暂不连, 后续 ARM 端轮询 AP_CTRL.IS_DONE 就够用. 后面需要再打开 IRQ_F2P.

# --- 地址分配 ---
puts "=== Assign addresses ==="
# pov_project 控制寄存器 (HLS 生成的 64KB 地址空间)
assign_bd_address -offset 0x43C20000 -range 64K \
    [get_bd_addr_segs {pov_project_0/s_axi_control/Reg}] -force
# pov 通过 HP1 访问 DDR (两个 m_axi 共享同一段地址空间)
assign_bd_address -offset 0x00000000 -range 1G \
    [get_bd_addr_segs {processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM}] -force

# --- VDMA: 2 framestores 做双缓冲 (默认 c_num_fstores=1 会撕裂) ---
puts "=== Set VDMA num_fstores = 2 (double buffering) ==="
if {[llength [get_bd_cells -quiet axi_vdma_0]]} {
    set_property -dict [list \
        CONFIG.c_num_fstores {2} \
    ] [get_bd_cells axi_vdma_0]
}

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Build bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth status: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl status: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
