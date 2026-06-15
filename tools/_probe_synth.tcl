open_project 02_hello_zynq.xpr
open_run synth_1 -name synth_1
puts "=== top ports sensor ==="
puts "sensor_pulse port: [get_ports -quiet sensor_pulse]"
puts "=== angle_tracker cells ==="
puts "u_angle: [get_cells -quiet -hier *u_angle_trk*]"
puts "=== IP hub75e cell sensor pin driver ==="
set p [get_pins -quiet -hier *hub75e_panel_seq*/sensor_pulse]
puts "ip sensor pin: $p"
catch { puts "net: [get_nets -quiet -of_objects $p]" }
puts "=== slice_idx_live / trk 相关 net ==="
puts "trk_slice nets: [get_nets -quiet -hier *trk_slice*]"
puts "fetch_slice: [get_cells -quiet -hier *fetch_slice*]"
