# rebuild_pov_ip2.tcl — Same-process synth+impl flow that avoids launch_runs spawn.
# Uses direct synth_design / place_design / route_design / write_bitstream.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set ip_repo "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"
set lib_repo "D:/workspace/zynq_pov/vivado-library"

puts "=== Open project ==="
open_project $proj_xpr
set_property ip_repo_paths [list $ip_repo $lib_repo] [current_project]
update_ip_catalog -rebuild

puts "=== Upgrade pov_project_batch IPs ==="
set pov_ips [get_ips -filter {IPDEF =~ "*pov_project_batch*"}]
puts "Found: $pov_ips"
foreach ip $pov_ips { upgrade_ip $ip }

puts "=== Regenerate BD output products ==="
generate_target all [get_files hello_zynq.bd] -force

puts "=== synth_design (direct, no spawn) ==="
set top "hello_zynq_wrapper"
synth_design -top $top -part xc7z020clg484-2
write_checkpoint -force $proj_dir/post_synth.dcp

puts "=== opt + place + route ==="
opt_design
place_design
route_design
write_checkpoint -force $proj_dir/post_route.dcp

puts "=== write_bitstream ==="
set bit_out "$proj_dir/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
file mkdir [file dirname $bit_out]
write_bitstream -force $bit_out

puts "=== export XSA ==="
write_hw_platform -fixed -include_bit -force -file "$proj_dir/hello_zynq_wrapper.xsa"

puts "=== DONE ==="
close_project
exit 0
