# Force pick up row_out: try update_module_reference, then re-save BD
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "before update, pins: [get_bd_pins led_panel_seq_0/*]"
if {[catch {update_module_reference led_panel_seq_0} err opts]} {
    puts "update_module_reference err: $err"
    puts "  opts: $opts"
}
puts "after update, pins: [get_bd_pins led_panel_seq_0/*]"

# 如果还是缺 row_out, 尝试 ipx::update_module_reference 或 reset_target
if {[get_bd_pins -quiet led_panel_seq_0/row_out] eq ""} {
    puts "row_out still missing. Trying reset_target + update_ip_catalog..."
    catch {reset_target -force all [get_files hello_zynq.bd]}
    catch {update_ip_catalog}
    if {[catch {update_module_reference led_panel_seq_0} err]} {
        puts "second update err: $err"
    }
    puts "after second update, pins: [get_bd_pins led_panel_seq_0/*]"
}

if {[get_bd_pins -quiet led_panel_seq_0/row_out] eq ""} {
    error "Cannot get row_out into cell"
}

# 重新连 row_out -> panel_seq_row (manual BD edit 的连接可能孤立了)
if {[get_bd_ports -quiet panel_seq_row] eq ""} {
    create_bd_port -dir O panel_seq_row
}
catch {disconnect_bd_net [get_bd_nets -of_objects [get_bd_ports panel_seq_row]] [get_bd_ports panel_seq_row]}
connect_bd_net [get_bd_pins led_panel_seq_0/row_out] [get_bd_ports panel_seq_row]

validate_bd_design
save_bd_design
generate_target all $bd_file
make_wrapper -files [get_files hello_zynq.bd] -top -import -force
puts "DONE: row_out connected"
exit 0
