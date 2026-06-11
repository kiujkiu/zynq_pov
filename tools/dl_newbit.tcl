puts "DL: starting (new bit + old ELF)"
set bit "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
fpga -file $bit
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
after 2000
puts "DL: done"
exit 0
