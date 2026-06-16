# anime 换回, LIVE 热换数据 (板子已配置, 不重烧 bit). sensor 模式保持.
# 停 DMA → 灌 anime 720 compact → sensor 配置重启
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0          ; # 停 DMA 干净收尾 (板 live, AXI 有效)
after 300
puts "loading anime 720 compact slices (5.76MB)..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_slices_720_compact.bin" 0x18000000
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x1FF        ; # 1-bit t_unit 255 满亮
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577        ; # fake fallback period
mwr -force 0x40020020 720          ; # N_SLICES
mwr -force 0x40020000 0xC5E1       ; # sensor_en=1
after 500
puts "ANIME sensor mode: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
