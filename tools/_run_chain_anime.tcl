# 全芯片链测试 (路线A): 注入点云+LUT → 跑 pov_chain.elf (ARM 体素化+触发pov_proj+配显示)
# 冷启动安全. 验证 "发点云, 体素化+切片+显示全芯片".
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/pov_chain/build/pov_chain.elf"
set PTS "D:/claude_workspace/pov3d/zynq_pov/tools/anime_points_hdr.bin"
set LUT "D:/claude_workspace/pov3d/zynq_pov/tools/transform_lut.bin"

connect
after 1000
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
configparams force-mem-access 1
puts "注入点云 (1.6MB) @ 0x16000000 ..."
dow -data $PTS 0x16000000
puts "注入 LUT @ 0x1B000000 ..."
dow -data $LUT 0x1B000000
# 跑 ARM 链 app
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
puts "pov_chain.elf 运行中 (ARM 体素化 + pov_proj 切片 ~700ms + 配显示)..."
after 3000
# xsdb 直读验证 (ARM 在 while(1))
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "APU*"}
puts "pov_proj AP_CTRL=[format 0x%X [mrd -force -value 0x43C20000]] (bit1=done)"
puts "显示: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
puts "grid0 (voxel_t @0x1C000000): [mrd -force 0x1C000000 2]"
puts "slice0 head (@0x18000000): [mrd -force 0x18000000 4]"
exit 0
