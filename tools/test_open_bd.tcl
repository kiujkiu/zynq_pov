open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
puts "project opened"
set bd_file [get_files hello_zynq.bd]
puts "bd file: $bd_file"
open_bd_design $bd_file
puts "bd opened"
exit 0
