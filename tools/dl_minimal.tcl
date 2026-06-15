# Minimal dl: NO rst -system (memory feedback_zynq_hdmi_stuck_after_rst.md)
# 直接 fpga + ps7_init + dow ELF, 让 PL 从 cold boot 后状态加载
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set anime  "D:/claude_workspace/pov3d/zynq_pov/anime_points.bin"

set anime_n 30803
set MODEL_ADDR  0x1A000000
set MAGIC_ADDR  0x1F000000
set MAGIC_VALUE 0xA11ECEC0

connect
after 1000
# NO rst -system here — leave PL state from cold boot
# v34o fix: 先停 ARM 再烧 PL — ARM 跑着写 PL 时 fpga reconfig 会卡死 AXI 事务
# (DAP sticky 0x30000021 根源), 之后只能拔电救
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
catch { targets -set -nocase -filter {name =~ "ARM*#1"}; stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
# v8 fix: 停 PL DMA 再重配置 (v6+ IP 是 HP2 master, 烧写时在飞的 AXI 读会卡死总线 → DAP sticky)
catch { mwr -force 0x40020000 0 }   ;# stop DMA before reconfig
after 200
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 100
dow $elf
catch { stop }
dow -data $anime $MODEL_ADDR
mwr [expr {$MAGIC_ADDR + 4}] $anime_n
mwr $MAGIC_ADDR $MAGIC_VALUE
con
after 3000
puts "done (no-rst-system version)"
exit 0
