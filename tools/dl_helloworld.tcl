puts "DL: starting"
set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/_ide/bitstream/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/_ide/psinit/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
puts "DL: connecting"
connect
puts "DL: connected, wait"
after 1500
puts "DL: targets APU"
targets -set -nocase -filter {name =~ "APU*"}
puts "DL: rst"
rst -system
after 1000
puts "DL: fpga"
fpga -file $bit
puts "DL: psinit"
source $psinit
ps7_init
ps7_post_config
puts "DL: targets ARM#0"
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL: dow"
dow $elf
puts "DL: con"
con
after 3000
puts "DL: exit"
exit 0
