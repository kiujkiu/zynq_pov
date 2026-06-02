# dl v28 bit (overlap+OE_PRE supported via CTRL[6])
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
puts "v28 dl OK. STATUS=[mrd 0x4002000C]"
exit 0
