# v6 DMA: 360 angle anime slices @ 0x18000000, 120 slice/s (3s/rev 肉眼可见扫掠)
connect
after 1000
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0       ; # 停显示, 防加载中读到半截
puts "loading 23MB slices (约 1 分钟)..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_slices_360.bin" 0x18000000
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x108        ; # 1-bit BCM
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 8681        ; # 8640 slice/s = 360 x 24Hz
mwr -force 0x40020020 360
mwr -force 0x40020000 0x5A1
after 500
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
after 2000
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
