open_project D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
puts "TOP before: [get_property TOP [get_filesets sources_1]]"
puts "src_mgmt: [get_property SOURCE_MGMT_MODE [current_project]]"

# Force ALL on source_mgmt
set_property source_mgmt_mode All [current_project]

# Try BD validate
open_bd_design [get_files hello_zynq.bd]
puts "==validate_bd_design=="
validate_bd_design
puts "==reports=="
report_ip_status
save_bd_design

# regen
puts "==generate_target=="
generate_target all [get_files hello_zynq.bd]
puts "==make_wrapper=="
catch {make_wrapper -files [get_files hello_zynq.bd] -top -force} err
puts "wrapper: $err"
close_bd_design hello_zynq

puts "TOP after: [get_property TOP [get_filesets sources_1]]"
close_project
