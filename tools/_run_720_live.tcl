# 720 片 @ 490 RPM, LIVE 热更新 (不重烧 bit, 零 JTAG 风险)
# 停 DMA → 灌 720 compact slices → N_SLICES=720 + ANGLE_PERIOD=14577 → 重启
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0          ; # CTRL=0 停 DMA, D_DRAIN 干净收尾
after 300
puts "loading 720 compact slices (5.76MB)..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_slices_720_compact.bin" 0x18000000
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x1FF        ; # 1-bit + t_unit 255 (满亮)
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577        ; # 490 RPM = 8.16Hz × 720 = 5880 slice/s
mwr -force 0x40020020 720          ; # N_SLICES = 720
mwr -force 0x40020000 0x45E1       ; # en|use_fb|overlap|dma_en|compact, sensor_en=0(fake)
after 500
puts "720 slices running: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]] N=[mrd -force -value 0x40020020]"
exit 0
