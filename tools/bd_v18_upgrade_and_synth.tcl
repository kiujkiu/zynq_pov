# Upgrade pov_project_batch IP 1.7 → 1.8 (depth-fade), then re-synth + bit + XSA.
# v1.8 adds rz-based brightness modulation in HLS output.

set prj "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr"
set ip_repo "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"
set xsa_out "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa"

puts "=== open project ==="
open_project $prj
set_property source_mgmt_mode None [current_project]

puts "=== refresh IP repo ==="
set existing [get_property ip_repo_paths [current_project]]
if {[lsearch $existing $ip_repo] < 0} {
    set_property ip_repo_paths [concat $existing $ip_repo] [current_project]
}
update_ip_catalog -rebuild -scan_changes

puts "=== open BD ==="
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "=== upgrade pov_project_batch IPs to v1.8 ==="
foreach idx {0 1 2 3} {
    set cell [get_bd_cells -quiet pov_project_batch_$idx]
    if {$cell ne ""} {
        puts "  IP$idx current VLNV: [get_property VLNV $cell]"
        set_property -dict [list CONFIG.Component_Name "hello_zynq_pov_project_batch_${idx}_0"] $cell
        upgrade_bd_cells $cell
        puts "  IP$idx new VLNV: [get_property VLNV $cell]"
    }
}

validate_bd_design
save_bd_design
generate_target all $bd_file
make_wrapper -files [get_files hello_zynq.bd] -top -import -force

puts "=== reset + synth + impl + bit ==="
reset_run synth_1
reset_run impl_1

# Try launch_runs (may fail per memory feedback_hls_resynth_full_flow)
if {[catch {launch_runs impl_1 -to_step write_bitstream -jobs 8} err]} {
    puts "launch_runs failed: $err"
    puts "FALLBACK: in-process synth + impl"
    synth_design -top hello_zynq_wrapper -part xc7z020clg484-2
    opt_design
    place_design
    route_design
    write_bitstream -force "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
} else {
    wait_on_run impl_1
    set st [get_property STATUS [get_runs impl_1]]
    puts "impl_1: $st"
    if {$st ne "write_bitstream Complete!"} {
        puts "FAIL: impl status $st"
        exit 1
    }
}

puts "=== export XSA ==="
if {[catch {open_run impl_1} err]} { puts "open_run skipped: $err" }
write_hw_platform -fixed -include_bit -force $xsa_out

puts "DONE: bit + XSA at"
puts "  bit: D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
puts "  xsa: $xsa_out"
close_project
exit 0
