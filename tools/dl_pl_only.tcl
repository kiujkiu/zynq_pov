# 只 dl bit + ps7_init, 不跑 ELF, ARM stay suspended (避免 ARM race xsdb mwr)
set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
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
stop
puts "PL loaded, PS7 init done, ARM suspended (not running ELF). xsdb can now safely mwr."
exit 0
