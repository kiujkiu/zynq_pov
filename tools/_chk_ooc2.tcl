open_project 02_hello_zynq.xpr
foreach ip [get_ips -quiet *hub75e*] {
    puts "IP: $ip"
    puts "  GENERATE_SYNTH_CHECKPOINT: [get_property GENERATE_SYNTH_CHECKPOINT $ip]"
    puts "  synth run: [get_runs -quiet ${ip}_synth_1]"
}
puts "=== module_ref 的 HDL 源 ==="
puts [get_property CONFIG.Component_Name [get_bd_cells hub75e_panel_seq_0]]
