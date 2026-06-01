connect
after 1500
targets
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "rst -processor"
rst -processor
after 1000
# 确保 bit 还在 PL, 只重启 ARM 跑 elf
set elf "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
puts "dow $elf"
dow $elf
puts "con"
con
after 500
puts "ARM restarted, demo cycle 应已开始"
disconnect
exit 0
