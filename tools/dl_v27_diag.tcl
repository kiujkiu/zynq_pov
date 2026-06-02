# dl bit + 不跑 ELF, 直接测 PL: disable → 应该黑屏; enable mode 6 → 应该 ramp
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1500
fpga -file $bit
after 1500
source $psinit
ps7_init
ps7_post_config
after 1000

# 关掉 ARM (不跑 ELF, 让 PS 处于 reset 让出 AXI)
# 直接用 force-mem-access 走 DAP 写 PL
configparams force-mem-access 1
after 200

puts "=== Step 1: disable (CTRL=0), panel 应该全黑 ==="
mwr 0x40020000 0
after 300
puts "STATUS = [mrd 0x4002000C]"
puts "[请看 panel: 现在应该是全黑]"
puts ""
after 5000

puts "=== Step 2: enable mode 7 FULL WHITE, TUNIT=16, addr_bits=5, use_fb=0 ==="
# CTRL = (5<<8) | (7<<1) | 1 = 0x50F
mwr 0x40020014 16
mwr 0x40020000 0x50F
after 300
puts "STATUS = [mrd 0x4002000C]"
puts "[请看 panel: 现在应该是全白]"
puts ""
after 5000

puts "=== Step 3: mode 6 GRADIENT, TUNIT=32 ==="
# CTRL = (5<<8) | (6<<1) | 1 = 0x50D
mwr 0x40020014 32
mwr 0x40020000 0x50D
after 300
puts "STATUS = [mrd 0x4002000C]"
puts "[请看 panel: 应该是 128 列横向灰阶 ramp, 左黑右白]"
puts ""
after 8000

puts "=== Step 4: mode 1 HSTRIPE (color stripes by row) ==="
# CTRL = (5<<8) | (1<<1) | 1 = 0x503
mwr 0x40020000 0x503
after 300
puts "STATUS = [mrd 0x4002000C]"
puts "[请看 panel: 应该是 8 行不同色 (red/green/blue/white/yellow/magenta/cyan/black 循环)]"

exit 0
