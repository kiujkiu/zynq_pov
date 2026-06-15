# 490 RPM (8.16Hz) 固定转速 + 满亮度, 一键部署
# 烧 bit + 360 compact slices + FCLK 85.7M + 1-bit + t_unit 255(满亮) + 490RPM
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
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
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
configparams force-mem-access 1
mwr -force 0x40020000 0x0
puts "loading 360 compact slices..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_slices_360_compact.bin" 0x18000000
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x1FF        ; # 1-bit + t_unit 255 (满亮)
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 29155        ; # 490 RPM = 8.16Hz × 360
mwr -force 0x40020020 360
mwr -force 0x40020000 0x45E1       ; # en|use_fb|overlap|dma_en|compact, sensor_en=0(fake)
after 500
puts "490 RPM running: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
