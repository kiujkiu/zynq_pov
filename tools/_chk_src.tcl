open_project 02_hello_zynq.xpr
puts "=== angle_tracker.v 在工程? ==="
puts [get_files -quiet *angle_tracker.v]
puts "=== hub75e v7 IP cell module ref ==="
open_bd_design [get_files hello_zynq.bd]
puts "cell ref: [get_property CONFIG.Component_Name [get_bd_cells hub75e_panel_seq_0]]"
puts "VLNV: [get_property VLNV [get_bd_cells hub75e_panel_seq_0]]"
