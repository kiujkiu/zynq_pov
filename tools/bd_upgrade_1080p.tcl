# bd_upgrade_1080p.tcl
# 把 HDMI 预览从 1280x720@60 升到 1920x1080@30.
#
# 关键洞察: 1080p30 的像素时钟 = 74.25 MHz, 和 720p60 完全一样.
# 所以不需要改 clk_wiz 或 FCLK_CLK1. 只改 VTC mode + VDMA 参数 + rgb2dvi.
#
# 要改 ARM 代码里的 WIDTH/HEIGHT/STRIDE/FRAME_BYTES (framebuffer 大小).

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Open project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# --- VTC: 生成 1080p 时序 (CEA VIC=16 1920x1080@30) ---
# VTC 的 Generator 参数:
#   generator_hactive_size=1920, hfrontporch_size=88, hsync_size=44, hbackporch_size=148 => htotal=2200
#   generator_vactive_size=1080, vfrontporch_size=4,  vsync_size=5,  vbackporch_size=36  => vtotal=1125
#   像素时钟 = 2200 * 1125 * 30 = 74.25 MHz (和原 720p60 像素时钟一致)
puts "=== Configure VTC for 1080p@30 ==="
set_property -dict [list \
    CONFIG.HAS_AXI4_LITE {true} \
    CONFIG.GEN_HACTIVE_SIZE {1920} \
    CONFIG.GEN_HFRONTPORCH_SIZE {88} \
    CONFIG.GEN_HSYNC_SIZE {44} \
    CONFIG.GEN_HBACKPORCH_SIZE {148} \
    CONFIG.GEN_VACTIVE_SIZE {1080} \
    CONFIG.GEN_VFRONTPORCH_SIZE {4} \
    CONFIG.GEN_VSYNC_SIZE {5} \
    CONFIG.GEN_VBACKPORCH_SIZE {36} \
    CONFIG.GEN_F0_VCHROMA_START {36} \
    CONFIG.GEN_F0_VACTIVE_START {36} \
    CONFIG.GEN_F0_VSYNC_VSTART {1121} \
    CONFIG.GEN_F0_VSYNC_VEND {1126} \
    CONFIG.GEN_F0_VFRAME_SIZE {1125} \
] [get_bd_cells v_tc_0]

# --- VDMA: 大 framebuffer 参数 ---
puts "=== Configure VDMA for 1080p ==="
# VDMA IP 核本身的 max size 要够 (HoriSize_bytes, VertSize); 如果参数固化,
# 运行时 ARM 再设 setup.HoriSizeInput=1920*3, VertSizeInput=1080, Stride=1920*3
# 这里只是 sanity check 它的 max burst / internal size.
# 老设置 c_include_sg=0 c_num_fstores=2 c_mm2s_linebuffer_depth=512 保持不变.
# linebuffer_depth=512 对 1920 像素宽可能不够, 升到 1024:
set_property -dict [list \
    CONFIG.c_mm2s_linebuffer_depth {1024} \
] [get_bd_cells axi_vdma_0]

# --- rgb2dvi: 1080p 时序内部无感知, 重建即可 ---
# Digilent rgb2dvi 会根据像素时钟自动处理. 因为像素时钟 74.25 MHz 未变, 无需改.

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
puts "=== DONE (1080p30 upgrade) ==="
exit 0
