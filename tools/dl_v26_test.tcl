# v26b overlap FSM: dl bit + setup mode 6 gradient + 测 E pin/帧率
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
after 1500

# 跑 ELF 让 hub75e_init 走一遍 (确保 enable bit 等 init OK)
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
after 3000

# 切 PL AXI 测试模式
configparams force-mem-access 1

# CTRL = (5<<8) | (6<<1) | 1 = 0x50D  mode 6 col gradient, addr_bits=5, en=1
mwr 0x40020014 8        ; # TUNIT = 8
mwr 0x40020000 0x50D    ; # CTRL: enable mode 6 gradient
after 200

# 读 STATUS 两次, diff frame_count (STATUS[31:16])
set s0 [lindex [mrd 0x4002000C] 1]
after 1000
set s1 [lindex [mrd 0x4002000C] 1]
puts ""
puts "=== Result ==="
puts "STATUS t0 = $s0"
puts "STATUS t1 = $s1"
# frame_count 取高 16 bit
set f0 [expr {0x$s0 >> 16}]
set f1 [expr {0x$s1 >> 16}]
set df [expr {($f1 - $f0) & 0xFFFF}]
puts "frame_count t0 = $f0  t1 = $f1  delta_1s = $df  (= 帧率 fps)"

exit 0
