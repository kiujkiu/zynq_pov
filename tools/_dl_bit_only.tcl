# Download bit only, NO ELF load
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 500
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
puts "bit downloaded, ARM not started"
exit 0
