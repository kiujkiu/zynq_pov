connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 300
catch { rst -processor }
after 500
targets -set -nocase -filter {name =~ "APU*"}
fpga -file "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
after 500
source "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
dow "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
dow -data "D:/claude_workspace/pov3d/zynq_pov/anime_points.bin" 0x1A000000
mwr 0x1F000004 30803
mwr 0x1F000000 0xA11ECEC0
con
after 2000
puts "RETRY-DL done"
exit 0
