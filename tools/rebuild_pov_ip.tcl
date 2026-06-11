# rebuild_pov_ip.tcl — Refresh HLS-generated pov_project_batch IP after re-synth,
# upgrade all 4 instances, regenerate BD output products, run synth+impl+bitgen,
# export XSA.
#
# Usage:
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch -source rebuild_pov_ip.tcl -nojournal

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set ip_repo "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"
set lib_repo "D:/workspace/zynq_pov/vivado-library"

puts "=== Open project ==="
open_project $proj_xpr

puts "=== Set IP repo paths ==="
set_property ip_repo_paths [list $ip_repo $lib_repo] [current_project]
update_ip_catalog -rebuild

puts "=== Find pov_project_batch instances ==="
set pov_ips [get_ips -filter {IPDEF =~ "*pov_project_batch*"}]
puts "Found IPs: $pov_ips"

puts "=== Force upgrade pov IPs ==="
foreach ip $pov_ips {
    puts "  upgrading $ip"
    upgrade_ip $ip
}

puts "=== Generate BD output products ==="
set bd [get_files hello_zynq.bd]
generate_target all $bd -force

puts "=== Reset runs ==="
catch { reset_run synth_1 }
catch { reset_run impl_1 }

puts "=== Synth (in-process, no spawn) ==="
launch_runs synth_1 -jobs 1
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 status: $synth_status"
if {[string first "Error" $synth_status] != -1 || [string first "FAILED" $synth_status] != -1} {
    error "Synth failed: $synth_status"
}

puts "=== Impl + bitstream ==="
launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "impl_1 status: $impl_status"

puts "=== Export hardware (XSA) ==="
set xsa_path "$proj_dir/hello_zynq_wrapper.xsa"
write_hw_platform -fixed -include_bit -force -file $xsa_path

puts "=== DONE. XSA: $xsa_path ==="
close_project
exit 0
