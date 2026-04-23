# bd_add_vdma.tcl
# 替换 VTPG 为 VDMA 帧缓冲: PS 写 DDR → VDMA 读 DDR → 视频输出管线
# 架构:
#   PS M_AXI_GP0 --[axi_smc]--> VDMA.S_AXI_LITE (控制)
#   VDMA.M_AXI_MM2S --[axi_smc_hp]--> PS S_AXI_HP0 --> DDR
#   VDMA.M_AXIS_MM2S --> v_axi4s_vid_out.video_in (原 VTPG 位置)
#   VTC 维持不变 (提供时序)

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Open project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# --- 删除旧地址段 (VTPG) ---
puts "=== Delete v_tpg address segment ==="
foreach seg {/processing_system7_0/Data/SEG_v_tpg_0_Reg} {
    set s [get_bd_addr_segs -quiet $seg]
    if {[llength $s]} { delete_bd_objs $s }
}

# --- 删除 VTPG 和 axi_smc 到 VTPG 的接口 ---
puts "=== Delete v_tpg_0 and its connections ==="
foreach intf {axi_smc/M02_AXI} {
    set n [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins $intf]]
    if {[llength $n]} { delete_bd_objs $n }
}
# v_tpg_0 的所有连线在删 cell 时会自动清理
if {[llength [get_bd_cells -quiet v_tpg_0]]} {
    delete_bd_objs [get_bd_cells v_tpg_0]
}

# --- PS 启用 S_AXI_HP0 ---
puts "=== PS enable S_AXI_HP0 ==="
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
] [get_bd_cells /processing_system7_0]

# --- 加 AXI VDMA ---
puts "=== Add axi_vdma_0 ==="
if {![llength [get_bd_cells -quiet axi_vdma_0]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0
}
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_num_fstores {1} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {24} \
    CONFIG.c_mm2s_genlock_mode {0} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_mm2s_linebuffer_depth {512} \
    CONFIG.c_mm2s_max_burst_length {16} \
] [get_bd_cells axi_vdma_0]

# --- 加 SmartConnect 给 VDMA → PS HP0 数据路径 ---
puts "=== Add axi_smc_hp for VDMA data path ==="
if {![llength [get_bd_cells -quiet axi_smc_hp]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp
}
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells axi_smc_hp]

# --- 连接数据路径: VDMA.M_AXI_MM2S → axi_smc_hp → PS.S_AXI_HP0 ---
puts "=== Wire VDMA data path ==="
connect_bd_intf_net [get_bd_intf_pins axi_vdma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins axi_smc_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_hp/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# --- 连接控制路径: axi_smc.M02 → VDMA.S_AXI_LITE ---
puts "=== Wire VDMA control path ==="
connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] \
                    [get_bd_intf_pins axi_vdma_0/S_AXI_LITE]

# --- 连接视频流: VDMA.M_AXIS_MM2S → v_axi4s_vid_out.video_in ---
puts "=== Wire VDMA video stream to S2V ==="
# 先断开原来 s2v.video_in 上的连接 (VTPG 删了之后可能已经悬空,但保险起见)
set vi [get_bd_intf_pins v_axi4s_vid_out_0/video_in]
foreach n [get_bd_intf_nets -quiet -of_objects $vi] { delete_bd_objs $n }
connect_bd_intf_net [get_bd_intf_pins axi_vdma_0/M_AXIS_MM2S] $vi

# --- 时钟连接 ---
puts "=== Wire clocks ==="
set fclk1 [get_bd_pins processing_system7_0/FCLK_CLK1]
# 清理可能的旧连接
foreach pin {
    axi_vdma_0/s_axi_lite_aclk
    axi_vdma_0/m_axi_mm2s_aclk
    axi_vdma_0/m_axis_mm2s_aclk
    axi_smc_hp/aclk
    processing_system7_0/S_AXI_HP0_ACLK
} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
}
# 全部统一到 FCLK_CLK1 (75MHz) 避免 VDMA 的
# "s_axi_lite_aclk <= m_axi_mm2s_aclk" 约束被违反
connect_bd_net $fclk1 [get_bd_pins axi_vdma_0/s_axi_lite_aclk]
connect_bd_net $fclk1 [get_bd_pins axi_vdma_0/m_axi_mm2s_aclk]
connect_bd_net $fclk1 [get_bd_pins axi_vdma_0/m_axis_mm2s_aclk]
connect_bd_net $fclk1 [get_bd_pins axi_smc_hp/aclk]
connect_bd_net $fclk1 [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK]

# --- 复位连接 (先断开再接, 避免已连接报错) ---
puts "=== Wire resets ==="
set rst50 [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
foreach pin {axi_vdma_0/axi_resetn axi_smc_hp/aresetn} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $rst50 $p
}

# --- 地址分配 ---
puts "=== Assign addresses ==="
# VDMA control register
assign_bd_address -offset 0x43C10000 -range 64K \
    [get_bd_addr_segs {axi_vdma_0/S_AXI_LITE/Reg}] -force
# VDMA accesses DDR via HP0
assign_bd_address -offset 0x00000000 -range 1G \
    [get_bd_addr_segs {processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM}] -force

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
