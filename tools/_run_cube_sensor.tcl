# 720 片 + 真实角度检测 (sensor_en=1), 烧 workaround bit (V14=panel_spi_miso 活信号)
# 热重烧: 先停 DMA → stop ARM → fpga → ps7_init → 720 数据 → CTRL sensor_en=1
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
connect
after 800
# 板子 LIVE 跑着 720, 先停 DMA 干净收尾 (AXI 此刻有效)
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0
after 400
# stop ARM 两核再烧 (避免烧 bit 瞬间 AXI 飞事务挂死 DAP)
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "ARM*#1"}
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
mwr -force 0x40020014 0x1FF        ; # 1-bit + t_unit 255 满亮
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577        ; # fake fallback period (sensor 丢脉冲时兜底)
mwr -force 0x40020020 720          ; # N_SLICES = 720
mwr -force 0x40020000 0xC5E1       ; # sensor_en=1 | en|use_fb|overlap|dma_en|compact
after 500
puts "SENSOR mode: CTRL=[format 0x%X [mrd -force -value 0x40020000]]"
puts "  DBG(0x24)=[format 0x%08X [mrd -force -value 0x40020024]]  rev_period(0x28)=[mrd -force -value 0x40020028]  sens_cnt(0x2C)=[mrd -force -value 0x4002002C]"
exit 0
