puts "QFW: starting QSPI flash writer flow"

set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set bootbin "D:/workspace/zynq_pov/tools/BOOT.bin"

# Get BOOT.bin size
set f [open $bootbin "rb"]
seek $f 0 end
set size [tell $f]
close $f
puts "QFW: BOOT.bin size = $size bytes"

connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 500
fpga -file $bit
source $psinit
ps7_init
ps7_post_config
# UART baud 921600
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

targets -set -nocase -filter {name =~ "ARM*#0"}

puts "QFW: loading BOOT.bin to DDR @ 0x10000000..."
dow -data $bootbin 0x10000000

puts "QFW: setting magic @ 0x18000000 + size @ 0x18000004"
mwr 0x18000000 0xFA571100
mwr 0x18000004 $size

puts "QFW: dow hello_world.elf"
dow $elf

puts "QFW: con (ARM runs flash writer; wait for qfw === flash write SUCCESS === in UART)"
con
puts "QFW: monitor UART for qfw log; after SUCCESS, 切拨码 S1=ON S2=OFF, 重启板子"
exit 0
