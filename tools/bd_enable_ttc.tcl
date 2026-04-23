# bd_enable_ttc.tcl
# 启用 PS TTC0 给 lwIP 提供硬件 timer

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

puts "=== Enable TTC0 ==="
set_property -dict [list \
    CONFIG.PCW_EN_TTC0 {1} \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_TTC0_TTC0_IO {EMIO} \
] [get_bd_cells /processing_system7_0]

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Synth + Impl + Bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth_1 status: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl_1 status: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
