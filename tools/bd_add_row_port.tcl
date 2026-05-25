# bd_add_row_port.tcl - 给 led_panel_seq IP 加 row_out 端口 + 外部 panel_seq_row port
# 简化版: set_property before open_project, single update_compile_order, then update_module_reference

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# update_module_reference 自动 detect 新加的端口并 refresh cell
puts "before update_module_reference, pins: [get_bd_pins led_panel_seq_0/*]"
if {[catch {update_module_reference led_panel_seq_0} err opts]} {
    puts "update_module_reference failed: err=$err opts=$opts"
}
puts "after update_module_reference, pins: [get_bd_pins led_panel_seq_0/*]"
if {[get_bd_pins -quiet led_panel_seq_0/row_out] eq ""} {
    puts "WARNING: row_out missing, falling back to remove + re-add"
    # 尝试: 把 Verilog 源从 fileset 移出再加回, 让 Vivado 重新 parse
    set v_file "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/led_panel_seq.v"
    remove_files $v_file
    add_files -norecurse $v_file
    update_compile_order -fileset sources_1
    if {[catch {update_module_reference led_panel_seq_0} err]} {
        puts "second update failed: $err"
    }
    puts "after re-add, pins: [get_bd_pins led_panel_seq_0/*]"
}

# 创建 panel_seq_row 外部 port + 连接
if {[get_bd_ports -quiet panel_seq_row] eq ""} {
    create_bd_port -dir O panel_seq_row
}
connect_bd_net [get_bd_pins led_panel_seq_0/row_out] \
    [get_bd_ports panel_seq_row]

validate_bd_design
save_bd_design
generate_target all $bd_file
make_wrapper -files [get_files hello_zynq.bd] -top -import -force

puts "DONE: panel_seq_row port added."
exit 0
