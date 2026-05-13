# rebuild_pov_ip3_single.tcl — Delete 3 unused pov_project_batch IP instances
# from BD (keep only IP 0_0 used by USE_PL=1 path), so the new 32K IP fits.
# Each 32K-deep IP uses ~144 BRAM. 4 instances = 576 (>280 available).
# 1 instance = 144 BRAM, fits comfortably.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set ip_repo "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"
set lib_repo "D:/workspace/zynq_pov/vivado-library"

puts "=== Open project ==="
open_project $proj_xpr
set_property ip_repo_paths [list $ip_repo $lib_repo] [current_project]
update_ip_catalog -rebuild

puts "=== Open BD ==="
open_bd_design [get_files hello_zynq.bd]

puts "=== Remove pov_project_batch_1/2/3 instances (keep _0 for USE_PL) ==="
foreach n {1 2 3} {
    set cell "/pov_project_batch_$n"
    if {[llength [get_bd_cells -quiet $cell]]} {
        puts "  removing $cell"
        delete_bd_objs [get_bd_cells $cell]
    } else {
        puts "  $cell not found, skip"
    }
}

puts "=== Also remove axi_smc_pov_hp slave AXI ports for those (S02-S07) ==="
# axi_smc_pov_hp has S00..S07 for IP 0..3 (2 ports each: gmem0 + gmem1)
# After removing IP 1,2,3 we should clean unused slave interfaces.
# This may auto-handle when we delete IPs. Try validate.

puts "=== Validate BD ==="
validate_bd_design
save_bd_design
close_bd_design [get_bd_designs *]

puts "=== Regenerate output products ==="
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
close_project
exit 0
