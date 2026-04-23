# bd_fix_eth_clock.tcl
# 加一个 FCLK_CLK2 @ 200 MHz 作为 gmii_to_rgmii 的参考时钟
# 解决 MMCM VCO 250MHz 超出 600-1440MHz 合法范围的 DRC 错误

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# -------- Step 1: PS 启用 FCLK_CLK2 @ 200 MHz --------
puts "=== Step 1: Enable FCLK_CLK2 @ 200 MHz ==="
set_property -dict [list \
    CONFIG.PCW_EN_CLK2_PORT {1} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL} \
] [get_bd_cells /processing_system7_0]
set actual [get_property CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ [get_bd_cells /processing_system7_0]]
puts "Actual FCLK_CLK2 freq: $actual MHz"

# -------- Step 2: 把 gmii_to_rgmii_0/clkin 从 FCLK_CLK0 改接 FCLK_CLK2 --------
puts "=== Step 2: Rewire gmii_to_rgmii clkin -> FCLK_CLK2 ==="
set p [get_bd_pins gmii_to_rgmii_0/clkin]
foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK2] $p

# -------- Step 3: validate & save --------
puts "=== Step 3: Validate & save ==="
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
