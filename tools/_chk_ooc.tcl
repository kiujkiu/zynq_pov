open_project 02_hello_zynq.xpr
set ip [get_files -quiet *hub75e_panel_seq_0*.bd]
puts "bd: $ip"
set xci [get_ips -quiet *hub75e_panel_seq_0*]
puts "ips: [get_ips -quiet]"
puts "=== synth checkpoint mode ==="
catch { puts [get_property GENERATE_SYNTH_CHECKPOINT [get_files -quiet *hub75e_panel_seq_0_3*]] }
puts "=== module_ref 综合方式 ==="
puts "BD OOC: [get_property synth_checkpoint_mode [get_files hello_zynq.bd]]"
