open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "=== external port sensor_pulse 存在? ==="
puts "port: [get_bd_ports -quiet sensor_pulse]"
puts "=== IP sensor_pulse 脚连到啥 net ==="
set ipin [get_bd_pins -quiet hub75e_panel_seq_0/sensor_pulse]
puts "ip pin: $ipin"
set net [get_bd_nets -quiet -of_objects $ipin]
puts "net: $net"
puts "net 上所有 pin/port: [get_bd_pins -quiet -of_objects $net] [get_bd_ports -quiet -of_objects $net]"
puts "=== xlconstant 还在? ==="
puts "[get_bd_cells -quiet xlconst_sensor0]"
