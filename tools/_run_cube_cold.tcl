# cube 冷启动部署: fpga 先, 再碰 AXI (冷板 PL 未配置, 先写 AXI 会挂总线锁 DAP)
# 烧 period-fix bit + cube 720 数据 + sensor 模式
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
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
puts "loading 720 CUBE compact slices (5.76MB)..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/cube_slices_720_compact.bin" 0x18000000
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x1FF        ; # 1-bit t_unit 255 满亮
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577        ; # fake fallback period
mwr -force 0x40020020 720          ; # N_SLICES
mwr -force 0x40020000 0xC5E1       ; # sensor_en=1
after 500
puts "CUBE sensor mode: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
