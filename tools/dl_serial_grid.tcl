# dl new serial-FSM bit + ps7_init + load grid fb + enable use_fb
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
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
after 1500

configparams force-mem-access 1
after 200

# Load grid fb (panel 物理拼接顺序反: top.bin → bot bank, bot.bin → top bank)
puts "loading fb_top.bin → 0x4002C000 ..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096
puts "loading fb_bot.bin → 0x40028000 ..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096

# TUNIT=32, CTRL: use_fb=1 mode=0 addr_bits=5 en=1 = 0x521
mwr 0x40020014 32
mwr 0x40020000 0x521
after 500
puts "CTRL=[mrd 0x40020000]"
puts "TUNIT=[mrd 0x40020014]"
puts "STATUS=[mrd 0x4002000C]"

# Read STATUS twice 1s apart to get fps (frame_count is now in [31:16])
set s0 [mrd -value 0x4002000C]
after 1000
set s1 [mrd -value 0x4002000C]
set f0 [expr {($s0 >> 16) & 0xFFFF}]
set f1 [expr {($s1 >> 16) & 0xFFFF}]
puts "frame_count delta over 1s = [expr {($f1 - $f0) & 0xFFFF}] fps"

exit 0
