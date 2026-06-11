connect
after 800
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/chess_1slice.bin" 0x18000000
mwr -force 0x40020014 0x608     ; # 6-bit 看清楚
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 75000000
mwr -force 0x40020020 1         ; # 单 slice 定住
mwr -force 0x40020000 0x5A1
after 500
puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
exit 0
