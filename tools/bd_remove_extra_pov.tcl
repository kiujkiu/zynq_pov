# bd_remove_extra_pov.tcl
# 把 pov_project_1/2/3 + smc_pov_hp2 + HP2 从 BD 删掉, 回到单 pov_project_0 的状态.
# 保留所有其他组件 (VDMA, VTC, rgb2dvi, pov_project_0, axi_smc_pov_hp 等).

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Open project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# --- 删地址段 ---
puts "=== Delete address segments ==="
foreach seg {
    /processing_system7_0/Data/SEG_pov_project_1_Reg
    /processing_system7_0/Data/SEG_pov_project_2_Reg
    /processing_system7_0/Data/SEG_pov_project_3_Reg
    /pov_project_1/Data_m_axi_gmem0/SEG_processing_system7_0_HP2_DDR_LOWOCM
    /pov_project_1/Data_m_axi_gmem1/SEG_processing_system7_0_HP2_DDR_LOWOCM
    /pov_project_2/Data_m_axi_gmem0/SEG_processing_system7_0_HP2_DDR_LOWOCM
    /pov_project_2/Data_m_axi_gmem1/SEG_processing_system7_0_HP2_DDR_LOWOCM
    /pov_project_3/Data_m_axi_gmem0/SEG_processing_system7_0_HP2_DDR_LOWOCM
    /pov_project_3/Data_m_axi_gmem1/SEG_processing_system7_0_HP2_DDR_LOWOCM
} {
    set s [get_bd_addr_segs -quiet $seg]
    if {[llength $s]} { delete_bd_objs $s }
}

# --- 删 4/5/6 M_AXI 接口连线 (会自动清理) ---
puts "=== Delete extra pov cells ==="
foreach cell {pov_project_1 pov_project_2 pov_project_3 smc_pov_hp2} {
    if {[llength [get_bd_cells -quiet $cell]]} {
        delete_bd_objs [get_bd_cells $cell]
    }
}

# --- axi_smc 回 4 M, 1 clk ---
puts "=== Shrink axi_smc to 4M 1-clock ==="
set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.NUM_CLKS {2} \
] [get_bd_cells axi_smc]

# --- axi_smc_pov_hp 回 2 S ---
puts "=== Shrink axi_smc_pov_hp to 2S ==="
set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] [get_bd_cells axi_smc_pov_hp]

# --- PS 关掉 HP2 (保留 HP1 for pov_project_0) ---
puts "=== Disable S_AXI_HP2 ==="
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP2 {0} \
] [get_bd_cells /processing_system7_0]

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Build bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
