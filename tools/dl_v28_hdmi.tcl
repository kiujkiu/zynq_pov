# dl v28 bit (has BOTH HDMI + HUB75E IP) + 33ccf54 ELF (HDMI-only) + anime
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set anime  "D:/claude_workspace/pov3d/zynq_pov/anime_points.bin"

set anime_n 30803
set MODEL_ADDR  0x1A000000
set MAGIC_ADDR  0x1F000000
set MAGIC_VALUE 0xA11ECEC0

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
catch { stop }
dow -data $anime $MODEL_ADDR
mwr [expr {$MAGIC_ADDR + 4}] $anime_n
mwr $MAGIC_ADDR $MAGIC_VALUE
con
after 3000
puts "done"
exit 0
