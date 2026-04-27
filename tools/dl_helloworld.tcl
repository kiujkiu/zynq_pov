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
# Override PS UART0 baud: ps7_init sets 115200 (BAUDGEN=0x7C), bump to 921600
# (BAUDGEN=0x12=18, BAUDDIV=5 @ 100MHz UART_REF_CLK, 0.5% 误差).
# Note: BAUDDIV 最小合法值=4, 不能用 BDIV=3 那组解.
# 8x wire speed for streaming. Done at JTAG level so ARM code can't revert.
puts "DL: setting UART baud=921600"
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
puts "DL: targets ARM#0"
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL: dow"
dow $elf
puts "DL: con"
con
after 3000
puts "DL: exit"
exit 0
