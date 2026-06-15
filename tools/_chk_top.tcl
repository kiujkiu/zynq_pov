open_project 02_hello_zynq.xpr
puts "synth top: [get_property top [get_filesets sources_1]]"
puts "=== open synth, list top ports with sensor ==="
open_run synth_1 -name s1
puts "all ports matching *sensor*: [get_ports -quiet *sensor*]"
puts "all ports matching *pulse*: [get_ports -quiet *pulse*]"
puts "top cell: [get_property top [current_design]]"
# 检查 wrapper netlist 顶层 port 总数
puts "total ports: [llength [get_ports]]"
