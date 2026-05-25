# bd_regen_wrapper.tcl - 重新生成 BD targets + wrapper, pick up 手动加的 panel_seq_row port
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file
puts "BD opened, checking row port..."
puts "  ports with 'row': [get_bd_ports -quiet {*row*}]"
puts "  led_panel_seq_0 pins: [get_bd_pins led_panel_seq_0/*]"
validate_bd_design
save_bd_design
puts "regenerating BD targets..."
generate_target all $bd_file
puts "regenerating wrapper..."
make_wrapper -files [get_files hello_zynq.bd] -top -import -force
puts "DONE"
exit 0
