set bit    "D:/claude_workspace/pov3d/zynq_pov_hdmi_test/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov_hdmi_test/02_hello_zynq/ps7_init.tcl"
set elf    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set anime  "D:/claude_workspace/pov3d/zynq_pov/anime_points.bin"

set anime_n 30803
set MODEL_ADDR  0x1A000000
set MAGIC_ADDR  0x1F000000
set MAGIC_VALUE 0xA11ECEC0

connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
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
puts "done (33ccf54 bit, no-rst-system, HUB75E disabled in ELF)"
exit 0
