
# Download bit + FSBL init + ELF and run lwip_echo_server
set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/_ide/bitstream/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/_ide/psinit/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/build/lwip_echo_server.elf"

puts "Connecting to hw_server..."
connect

puts "Selecting ARM CPU0..."
targets -set -nocase -filter {name =~ "APU*"}

puts "Resetting system..."
rst -system
after 1000

puts "Programming FPGA: $bit"
fpga -file $bit

puts "Sourcing ps7_init.tcl..."
source $psinit
ps7_init
ps7_post_config

puts "Selecting A9 core 0..."
targets -set -nocase -filter {name =~ "ARM*#0"}

puts "Downloading ELF: $elf"
dow $elf

puts "Starting CPU..."
con

puts "Running. Give it some time to init."
after 10000
puts "Done. Check serial for output."
disconnect
exit 0
