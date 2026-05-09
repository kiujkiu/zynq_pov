puts "QSPI VERIFY: starting full readback verify flow"

set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set bootbin "D:/workspace/zynq_pov/tools/BOOT.bin"

set f [open $bootbin "rb"]
seek $f 0 end
set size [tell $f]
close $f
puts "VERIFY: BOOT.bin size = $size bytes"

connect
after 1000
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 500
fpga -file $bit
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

targets -set -nocase -filter {name =~ "ARM*#0"}

puts "VERIFY: loading BOOT.bin to DDR @ 0x10000000..."
dow -data $bootbin 0x10000000

puts "VERIFY: setting magic 0xFA571101 + size @ 0x18000004"
mwr 0x18000000 0xFA571101
mwr 0x18000004 $size

puts "VERIFY: dow hello_world.elf"
dow $elf

puts "VERIFY: con — UART will show full readback compare"
con
exit 0
