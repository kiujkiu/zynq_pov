# HLS 板端测试: 烧新 bit + 注入 globe voxel+LUT → pov_proj 现算 720 片 → 显示
# 冷启动安全 (fpga 先再碰 AXI). pov_proj @ 0x43C20000 (control).
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set VOX  "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/hls_pov/tb_globe_voxel.bin"
set LUT  "D:/claude_workspace/pov3d/zynq_pov/tools/transform_lut.bin"

# pov_proj 寄存器 (base 0x43C20000)
set PB 0x43C20000
set AP     [expr {$PB+0x00}]
set R_VOX  [expr {$PB+0x10}]
set R_LUT  [expr {$PB+0x1C}]
set R_SB   [expr {$PB+0x28}]
set R_NT   [expr {$PB+0x34}]
set R_SS   [expr {$PB+0x3C}]
set R_NS   [expr {$PB+0x44}]

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

puts "注入 voxel grid (8MB) @ 0x1C000000 ..."
dow -data $VOX 0x1C000000
puts "注入 LUT (64KB) @ 0x1B000000 ..."
dow -data $LUT 0x1B000000

# pov_proj 参数
mwr -force $R_VOX 0x1C000000
mwr -force $R_LUT 0x1B000000
mwr -force $R_SB  0x18000000
mwr -force $R_NT  720
mwr -force $R_SS  0
mwr -force $R_NS  720
# ap_start
puts "ap_start, 等 pov_proj 算 720 片..."
mwr -force $AP 0x1
# poll ap_done (bit1), 超时保护
set done 0
for {set i 0} {$i < 200} {incr i} {
    after 50
    set ctrl [mrd -force -value $AP]
    if {$ctrl & 0x2} { set done 1; break }
}
puts "pov_proj AP_CTRL=[format 0x%X [mrd -force -value $AP]]  done=$done (iters=$i, ~[expr {$i*50}]ms)"

# 配显示 IP (sensor 模式 720 片, 读 pov_proj 写的 0x18000000)
mwr -force 0xF8000180 0x00300700   ; # FCLK1 85.7M
mwr -force 0x40020014 0x1FF
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577
mwr -force 0x40020020 720
mwr -force 0x40020000 0xC5E1
after 500
puts "显示: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
# 抽查 pov_proj 写的第 0 片头几个 word (应非全 0)
puts "slice0 head: [mrd -force 0x18000000 4]"
exit 0
