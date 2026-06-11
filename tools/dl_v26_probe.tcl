# 探测 v26b PL 是否真的活着: 先写 PS DDR (一定 OK), 再读 hub75e STATUS
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1500
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
after 2000

# 跑 ELF 让 ARM 启动 (会自动 hub75e_init 然后跑 bringup_main)
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
after 3000  ; # 等 ARM 跑 init

# 切回 APU 看 PL AXI
targets -set -nocase -filter {name =~ "APU*"}

# 现在 ARM 已经 enable hub75e, 读 STATUS
puts ""
puts "=== Read STATUS over 1s ==="
set s0 [mrd -force 0x4002000C]
after 1000
set s1 [mrd -force 0x4002000C]
puts "STATUS t0 = $s0"
puts "STATUS t1 = $s1"

exit 0
