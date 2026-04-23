# bd_revert_to_720p.tcl - 保留 4-IP, 回滚 VTC 时序 / VDMA linebuffer 到 720p 配置.
# 1080p 引发 HDMI 消失; 先退回稳定状态.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Open project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# --- VTC 回 720p60 ---
puts "=== Revert VTC to 720p60 ==="
set_property -dict [list \
    CONFIG.GEN_HACTIVE_SIZE {1280} \
    CONFIG.GEN_HFRONTPORCH_SIZE {110} \
    CONFIG.GEN_HSYNC_SIZE {40} \
    CONFIG.GEN_HBACKPORCH_SIZE {220} \
    CONFIG.GEN_VACTIVE_SIZE {720} \
    CONFIG.GEN_VFRONTPORCH_SIZE {5} \
    CONFIG.GEN_VSYNC_SIZE {5} \
    CONFIG.GEN_VBACKPORCH_SIZE {20} \
    CONFIG.GEN_F0_VBLANK_HSTART {721} \
    CONFIG.GEN_F0_VBLANK_HEND {1} \
    CONFIG.GEN_F0_VSYNC_VSTART {725} \
    CONFIG.GEN_F0_VSYNC_VEND {730} \
    CONFIG.GEN_F0_VSYNC_HSTART {1281} \
    CONFIG.GEN_F0_VSYNC_HEND {1281} \
    CONFIG.GEN_F0_VFRAME_SIZE {750} \
    CONFIG.GEN_F0_VACTIVE_START {25} \
    CONFIG.GEN_F0_VCHROMA_START {25} \
    CONFIG.GEN_HACTIVE_START {260} \
    CONFIG.GEN_HFRAME_SIZE {1650} \
] [get_bd_cells v_tc_0]

# --- VDMA linebuffer 回 512 ---
puts "=== Revert VDMA linebuffer to 512 ==="
set_property -dict [list \
    CONFIG.c_mm2s_linebuffer_depth {512} \
] [get_bd_cells axi_vdma_0]

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
