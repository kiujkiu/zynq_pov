# v7 紧凑格式全速: 360 slice × 24Hz = 8640 独立片/秒
connect
after 1000
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_slices_360_compact.bin" 0x18000000
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x108        ; # 1-bit
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 9920         ; # 85.71M / 8640 = 24Hz x 360
mwr -force 0x40020020 360
mwr -force 0x40020000 0x45E1       ; # enable|use_fb|overlap|dma_en|abits5|compact(bit14)
after 500
for {set i 0} {$i < 3} {incr i} {
    puts "DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
    after 1000
}
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
puts "panel fps=[expr {((($f2>>16)-($f1>>16))&0xFFFF)/2}]"
exit 0
