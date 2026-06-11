puts "DL-POR: starting (power-on-reset variant)"
set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
puts "DL-POR: rst -por"
rst -por
after 2000
puts "DL-POR: fpga"
fpga -file $bit
puts "DL-POR: psinit"
source $psinit
ps7_init
ps7_post_config
puts "DL-POR: UART baud=921600"
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL-POR: dow"
dow $elf
puts "DL-POR: con"
con
after 3000
puts "DL-POR: exit"
exit 0
