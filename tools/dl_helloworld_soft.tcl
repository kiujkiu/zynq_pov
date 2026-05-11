# Soft dl: 不 rst -system, 保 DDR 内 model 数据.
# 用法: 先用 dl_helloworld.tcl 跑过 + send model 完成后, 再用此脚本 dl 新 elf
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
puts "DL_soft: connecting"
connect
after 500
puts "DL_soft: targets ARM#0"
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL_soft: stop"
stop
after 200
puts "DL_soft: setting UART baud=921600 (保险)"
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
puts "DL_soft: dow new elf (DDR + bit 不变)"
dow $elf
puts "DL_soft: con"
con
after 1000
puts "DL_soft: exit"
exit 0
