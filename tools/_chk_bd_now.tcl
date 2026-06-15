open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "=== sensor_pulse 脚的 net + 源 ==="
set p [get_bd_pins -quiet hub75e_panel_seq_0/sensor_pulse]
set net [get_bd_nets -quiet -of_objects $p]
puts "net: $net"
puts "net 上 pins: [get_bd_pins -quiet -of_objects $net]"
puts "net 上 ports: [get_bd_ports -quiet -of_objects $net]"
puts "=== 有没有残留 xlconstant 驱 sensor ==="
foreach c [get_bd_cells -quiet -filter {VLNV =~ *xlconstant*}] {
    puts "$c -> [get_bd_nets -quiet -of_objects [get_bd_pins $c/dout]]"
}
puts "=== external port sensor_pulse ==="
puts "[get_bd_ports -quiet sensor_pulse]"
