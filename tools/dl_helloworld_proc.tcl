puts "DL-PROC: starting (processor-only reset, preserve PS SDIO state)"
set elf "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "DL-PROC: rst -processor"
rst -processor
after 500
puts "DL-PROC: dow"
dow $elf
puts "DL-PROC: con"
con
after 3000
puts "DL-PROC: exit"
exit 0
