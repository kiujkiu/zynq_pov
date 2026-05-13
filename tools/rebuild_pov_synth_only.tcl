# Just synth+impl on existing project (BD already cleaned by previous run)
set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set ip_repo "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"
set lib_repo "D:/workspace/zynq_pov/vivado-library"

open_project $proj_xpr
set_property ip_repo_paths [list $ip_repo $lib_repo] [current_project]
update_ip_catalog -rebuild

puts "=== Regenerate BD output products (BD already has 1 IP only) ==="
generate_target all [get_files hello_zynq.bd] -force

puts "=== synth_design ==="
synth_design -top hello_zynq_wrapper -part xc7z020clg484-2
write_checkpoint -force $proj_dir/post_synth.dcp

puts "=== opt + place + route ==="
opt_design
place_design
route_design
write_checkpoint -force $proj_dir/post_route.dcp

puts "=== write_bitstream ==="
write_bitstream -force "$proj_dir/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"

puts "=== DONE ==="
exit 0
