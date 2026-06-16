open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
set sp [get_bd_pins -quiet hub75e_panel_seq_0/sensor_pulse]
puts "sensor_pulse pin: $sp"
puts "  driven by net: [get_bd_nets -quiet -of_objects $sp]"
puts "  net source pins: [get_bd_pins -quiet -of_objects [get_bd_nets -quiet -of_objects $sp]]"
puts "panel_spi_miso 端口: [get_bd_ports -quiet *panel_spi_miso*]"
foreach p [get_bd_ports -quiet *panel_spi_miso*] { puts "  $p net=[get_bd_nets -quiet -of_objects $p] -> pins [get_bd_pins -quiet -of_objects [get_bd_nets -quiet -of_objects $p]]" }
puts "sensor_pulse 外部端口? [get_bd_ports -quiet *sensor*]"
close_project
exit 0
