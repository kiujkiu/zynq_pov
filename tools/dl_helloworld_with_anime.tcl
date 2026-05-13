puts "DL-ANIME: full cold boot + JTAG-inject anime model"
set bit    "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf    "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
set anime  "D:/workspace/zynq_pov/anime_points.bin"

# anime point count is byte_count / 16. We pass it as argument or hardcode.
# 30803 points × 16 bytes = 492848 bytes
set anime_n 30803

set MODEL_ADDR  0x1A000000
set MAGIC_ADDR  0x1F000000
set MAGIC_VALUE 0xA11ECEC0

puts "DL-ANIME: connect"
connect
after 1500
puts "DL-ANIME: targets APU"
targets -set -nocase -filter {name =~ "APU*"}
puts "DL-ANIME: rst -system"
rst -system
after 1000
puts "DL-ANIME: fpga -file (PL bitstream)"
fpga -file $bit
puts "DL-ANIME: ps7_init"
source $psinit
ps7_init
ps7_post_config
# Set UART baud 921600 (same as dl_helloworld.tcl)
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

puts "DL-ANIME: targets ARM#0"
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL-ANIME: download ELF"
dow $elf
# ARM is halted at entry after dow. Inject data while halted.
catch { stop }

puts "DL-ANIME: write anime bin to $MODEL_ADDR ([file size $anime] bytes)"
dow -data $anime $MODEL_ADDR
puts "DL-ANIME: write anime_n=$anime_n at $MAGIC_ADDR+4"
set n_addr [expr {$MAGIC_ADDR + 4}]
mwr $n_addr $anime_n
puts "DL-ANIME: write magic at $MAGIC_ADDR"
mwr $MAGIC_ADDR $MAGIC_VALUE
# Verify
puts "DL-ANIME: verify magic+count"
puts [mrd $MAGIC_ADDR 2]
puts "DL-ANIME: verify first 16 bytes of model data"
puts [mrd $MODEL_ADDR 4]

puts "DL-ANIME: continue ARM"
con
after 3000
puts "DL-ANIME: done"
exit 0
