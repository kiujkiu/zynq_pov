# v6 DMA bring-up: 8 纯色 slice @ 0x13000000, 假角度 1 slice/s
connect
after 1000
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "loading test slices..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/slices_test.bin" 0x13000000
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x608        ; # 6-bit BCM
mwr -force 0x40020008 127
mwr -force 0x40020018 0x13000000   ; # SLICE_BASE
mwr -force 0x4002001C 75000000     ; # ANGLE_PERIOD = 1 slice/s
mwr -force 0x40020020 8            ; # N_SLICES
mwr -force 0x40020000 0x5A1        ; # enable|use_fb|dma_en|abits5
after 500
for {set i 0} {$i < 6} {incr i} {
    puts "DBG(0x24)=[format 0x%08X [mrd -force -value 0x40020024]] STATUS=[format 0x%08X [mrd -force -value 0x4002000C]]"
    after 1500
}
exit 0
