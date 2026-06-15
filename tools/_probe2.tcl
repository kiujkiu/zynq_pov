open_project 02_hello_zynq.xpr
open_run synth_1 -name s2
puts "=== 计数器 cells ==="
puts "sens_pulse_cnt: [llength [get_cells -quiet -hier *sens_pulse_cnt*]]"
puts "sens_sync: [llength [get_cells -quiet -hier *sens_sync*]]"
puts "=== IP sensor 脚 driver ==="
set p [get_pins -quiet -hier */sensor_pulse]
puts "pins: $p"
foreach pp $p { puts "  $pp <- [get_nets -quiet -of_objects $pp]" }
puts "=== angle_tracker 内部 reg (rev_cnt 等) ==="
puts "rev: [llength [get_cells -quiet -hier *rev_period*]] slice_idx: [llength [get_cells -quiet -hier *u_angle*slice_idx*]]"
