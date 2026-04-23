set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/_ide/bitstream/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/_ide/psinit/ps7_init.tcl"
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
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
after 3000
exit 0
