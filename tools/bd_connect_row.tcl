# Connect row_out -> panel_seq_row + regen wrapper
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "led_panel_seq_0 pins: [get_bd_pins led_panel_seq_0/*]"
puts "panel_seq_row port: [get_bd_ports -quiet panel_seq_row]"

# 确认 row_out 在 cell 上, port 也存在
if {[get_bd_pins -quiet led_panel_seq_0/row_out] eq ""} {
    error "row_out pin missing on led_panel_seq_0"
}
if {[get_bd_ports -quiet panel_seq_row] eq ""} {
    puts "creating port panel_seq_row"
    create_bd_port -dir O panel_seq_row
}

# 删 orphaned net 然后重新 connect
foreach net [get_bd_nets -quiet led_panel_seq_0_row_out] {
    puts "removing orphaned net $net"
    delete_bd_objs $net
}

connect_bd_net [get_bd_pins led_panel_seq_0/row_out] [get_bd_ports panel_seq_row]
puts "connected row_out -> panel_seq_row"

validate_bd_design
save_bd_design
generate_target all $bd_file
make_wrapper -files [get_files hello_zynq.bd] -top -import -force

puts "DONE"
exit 0
